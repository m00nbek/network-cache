import Foundation

/// Manages cache expiration and automatic cleanup
actor ExpirationManager {
    private let memoryCache: MemoryCache
    private let diskCache: DiskCache
    private let cleanupInterval: TimeInterval
    private var cleanupTask: Task<Void, Never>?
    private var isRunning = false
    
    init(memoryCache: MemoryCache, diskCache: DiskCache, cleanupInterval: TimeInterval) {
        self.memoryCache = memoryCache
        self.diskCache = diskCache
        self.cleanupInterval = cleanupInterval
    }
    
    /// Start automatic cleanup in the background
    func startAutomaticCleanup() {
        guard !isRunning else { return }
        isRunning = true
        
        cleanupTask = Task {
            while !Task.isCancelled {
                // Perform cleanup
                await performCleanup()
                
                // Wait for next cleanup interval
                try? await Task.sleep(nanoseconds: UInt64(cleanupInterval * 1_000_000_000))
            }
        }
    }
    
    /// Stop automatic cleanup
    func stopAutomaticCleanup() {
        isRunning = false
        cleanupTask?.cancel()
        cleanupTask = nil
    }
    
    /// Manually trigger a cleanup operation
    func performCleanup() async {
        // Remove expired entries from memory cache
        let memoryRemoved = await memoryCache.removeExpiredEntries()
        
        // Remove expired entries from disk cache
        let diskRemoved = await diskCache.removeExpiredEntries()
        
        #if DEBUG
        if memoryRemoved > 0 || diskRemoved > 0 {
            print("[ExpirationManager] Cleaned up \(memoryRemoved) memory entries and \(diskRemoved) disk entries")
        }
        #endif
    }
    
    /// Force eviction of LRU entries if cache is over capacity
    func evictIfNeeded() async {
        // Check disk cache size
        _ = await diskCache.getStatistics()
        
        // Note: Eviction is handled automatically by DiskCache when setting new entries
        // This method is here for future manual eviction triggers if needed
    }
}
