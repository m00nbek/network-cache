import Foundation

/// Main network cache coordinator combining memory and disk caches
public final class NetworkCache: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = NetworkCache(configuration: .default)
    
    private let memoryCache: MemoryCache
    private let diskCache: DiskCache
    private let configuration: NetworkCacheConfiguration
    private let expirationManager: ExpirationManager
    private let offlineHandler: OfflineModeHandler?
    
    /// Statistics tracking
    private var hits: Int = 0
    private var misses: Int = 0
    
    /// Request deduplication: track in-flight requests
    private var inFlightRequests: [String: Task<CacheEntry?, Error>] = [:]
    
    /// Create a new NetworkCache instance with custom configuration
    public init(configuration: NetworkCacheConfiguration = .default) {
        self.configuration = configuration
        
        // Initialize memory cache
        self.memoryCache = MemoryCache(capacity: configuration.memoryCapacity)
        
        // Initialize disk cache
        do {
            self.diskCache = try DiskCache(
                directory: configuration.diskCacheDirectory,
                capacity: configuration.diskCapacity
            )
        } catch {
            fatalError("Failed to initialize disk cache: \(error)")
        }
        
        // Initialize expiration manager
        self.expirationManager = ExpirationManager(
            memoryCache: memoryCache,
            diskCache: diskCache,
            cleanupInterval: configuration.cleanupInterval
        )
        
        // Initialize offline handler if enabled
        if configuration.offlineModeEnabled {
            self.offlineHandler = OfflineModeHandler(
                diskCache: diskCache,
                maxStaleAge: configuration.maxStaleAge
            )
        } else {
            self.offlineHandler = nil
        }
        
        // Start background cleanup
        Task { await expirationManager.startAutomaticCleanup() }
    }
    
    deinit {
        // Note: Can't call async methods in deinit, cleanup will happen when actor is deallocated
    }
    
    // MARK: - Public API
    
    /// Retrieve cached data for a key
    /// - Parameter key: The cache key
    /// - Returns: Cached data if available and not expired, nil otherwise
    public func get(key: CacheKey) async throws -> Data? {
        let keyHash = key.hashedValue
        
        // Check for in-flight request (request deduplication)
        if let existingTask = await getInFlightTask(for: keyHash) {
            let entry = try await existingTask.value
            return entry?.data
        }
        
        // Check memory cache first
        if let entry = await memoryCache.get(for: key) {
            if !entry.isExpired() {
                await recordHit()
                if configuration.debugLogging {
                    print("[NetworkCache] Memory hit: \(key.debugDescription)")
                }
                return entry.data
            } else {
                // Remove expired entry
                await memoryCache.remove(for: key)
            }
        }
        
        // Check disk cache
        do {
            if let entry = try await diskCache.get(for: key) {
                if !entry.isExpired() {
                    // Promote to memory cache
                    await memoryCache.set(entry, for: key)
                    await recordHit()
                    if configuration.debugLogging {
                        print("[NetworkCache] Disk hit: \(key.debugDescription)")
                    }
                    return entry.data
                } else {
                    // Remove expired entry
                    try await diskCache.remove(for: key)
                }
            }
        } catch {
            if configuration.debugLogging {
                print("[NetworkCache] Disk read error: \(error)")
            }
        }
        
        // Check offline mode for stale cache
        if let offlineHandler = offlineHandler,
           await offlineHandler.isOffline() {
            if let staleData = await offlineHandler.getStaleData(for: key) {
                await recordHit()
                if configuration.debugLogging {
                    print("[NetworkCache] Offline mode: serving stale cache for \(key.debugDescription)")
                }
                return staleData
            }
        }
        
        await recordMiss()
        if configuration.debugLogging {
            print("[NetworkCache] Miss: \(key.debugDescription)")
        }
        return nil
    }
    
    /// Store data in cache
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: The cache key
    ///   - ttl: Time-to-live in seconds (nil uses default from configuration)
    public func set(_ data: Data, for key: CacheKey, ttl: TimeInterval? = nil) async throws {
        let effectiveTTL = ttl ?? configuration.defaultTTL
        
        let entry = CacheEntry(
            data: data,
            ttl: effectiveTTL,
            metadata: CacheEntry.Metadata(url: key.url)
        )
        
        // Store in both memory and disk
        await memoryCache.set(entry, for: key)
        
        do {
            try await diskCache.set(entry, for: key)
            if configuration.debugLogging {
                print("[NetworkCache] Stored: \(key.debugDescription) (TTL: \(effectiveTTL)s)")
            }
        } catch {
            if configuration.debugLogging {
                print("[NetworkCache] Disk write error: \(error)")
            }
            throw error
        }
    }
    
    /// Remove a specific entry from cache
    /// - Parameter key: The cache key to remove
    public func remove(key: CacheKey) async throws {
        await memoryCache.remove(for: key)
        try await diskCache.remove(for: key)
        
        if configuration.debugLogging {
            print("[NetworkCache] Removed: \(key.debugDescription)")
        }
    }
    
    /// Clear all cache entries
    public func clear() async throws {
        await memoryCache.removeAll()
        try await diskCache.removeAll()
        await resetStatistics()
        
        if configuration.debugLogging {
            print("[NetworkCache] Cleared all cache")
        }
    }
    
    /// Check if a key exists in cache (doesn't update access time)
    /// - Parameter key: The cache key to check
    /// - Returns: True if the key exists in cache
    public func contains(key: CacheKey) async -> Bool {
        if await memoryCache.contains(key: key) {
            return true
        }
        return await diskCache.contains(key: key)
    }
    
    /// Get cache statistics
    /// - Returns: Current cache statistics
    public func statistics() async -> CacheStatistics {
        let memoryStats = await memoryCache.getStatistics()
        let diskStats = await diskCache.getStatistics()
        
        return CacheStatistics(
            hits: hits,
            misses: misses,
            memorySize: memoryStats.estimatedSize,
            diskSize: diskStats.size,
            memoryEntryCount: memoryStats.entryCount,
            diskEntryCount: diskStats.entryCount
        )
    }
    
    // MARK: - Private Helpers
    
    private func getInFlightTask(for keyHash: String) async -> Task<CacheEntry?, Error>? {
        return inFlightRequests[keyHash]
    }
    
    private func setInFlightTask(_ task: Task<CacheEntry?, Error>?, for keyHash: String) async {
        if let task = task {
            inFlightRequests[keyHash] = task
        } else {
            inFlightRequests.removeValue(forKey: keyHash)
        }
    }
    
    private func recordHit() async {
        hits += 1
    }
    
    private func recordMiss() async {
        misses += 1
    }
    
    private func resetStatistics() async {
        hits = 0
        misses = 0
    }
}

// MARK: - Convenience Extensions

extension NetworkCache {
    /// Create a cache key from URL and method
    public static func key(url: String, method: String = "GET", headers: [String: String]? = nil) -> CacheKey {
        CacheKey(url: url, method: method, headers: headers)
    }
    
    /// Create a cache key with HTTPMethod enum
    public static func key(url: String, method: CacheKey.HTTPMethod, headers: [String: String]? = nil) -> CacheKey {
        CacheKey(url: url, method: method, headers: headers)
    }
}
