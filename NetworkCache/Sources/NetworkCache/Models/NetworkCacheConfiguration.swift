import Foundation

/// Configuration options for NetworkCache
public struct NetworkCacheConfiguration: Sendable {
    /// Maximum memory cache size in bytes (default: 50MB)
    public let memoryCapacity: Int
    
    /// Maximum disk cache size in bytes (default: 500MB)
    public let diskCapacity: Int
    
    /// Default time-to-live for cache entries in seconds (default: 24 hours)
    public let defaultTTL: TimeInterval
    
    /// Interval between automatic cleanup operations in seconds (default: 1 hour)
    public let cleanupInterval: TimeInterval
    
    /// Enable offline mode (serve stale cache when offline)
    public let offlineModeEnabled: Bool
    
    /// Maximum age for stale cache entries in offline mode (default: 7 days)
    public let maxStaleAge: TimeInterval
    
    /// Directory name for disk cache (default: "com.networkcache.data")
    public let diskCacheDirectory: String
    
    /// Enable LRU eviction when cache size limits are reached
    public let lruEvictionEnabled: Bool
    
    /// Enable debug logging
    public let debugLogging: Bool
    
    public init(
        memoryCapacity: Int = 50 * 1024 * 1024,        // 50MB
        diskCapacity: Int = 500 * 1024 * 1024,          // 500MB
        defaultTTL: TimeInterval = 24 * 60 * 60,        // 24 hours
        cleanupInterval: TimeInterval = 60 * 60,        // 1 hour
        offlineModeEnabled: Bool = false,
        maxStaleAge: TimeInterval = 7 * 24 * 60 * 60,   // 7 days
        diskCacheDirectory: String = "com.networkcache.data",
        lruEvictionEnabled: Bool = true,
        debugLogging: Bool = false
    ) {
        self.memoryCapacity = memoryCapacity
        self.diskCapacity = diskCapacity
        self.defaultTTL = defaultTTL
        self.cleanupInterval = cleanupInterval
        self.offlineModeEnabled = offlineModeEnabled
        self.maxStaleAge = maxStaleAge
        self.diskCacheDirectory = diskCacheDirectory
        self.lruEvictionEnabled = lruEvictionEnabled
        self.debugLogging = debugLogging
    }
    
    /// Default configuration
    public static let `default` = NetworkCacheConfiguration()
    
    /// Aggressive caching configuration (longer TTL, larger cache)
    public static let aggressive = NetworkCacheConfiguration(
        memoryCapacity: 100 * 1024 * 1024,      // 100MB
        diskCapacity: 1024 * 1024 * 1024,       // 1GB
        defaultTTL: 7 * 24 * 60 * 60,           // 7 days
        offlineModeEnabled: true
    )
    
    /// Conservative caching configuration (shorter TTL, smaller cache)
    public static let conservative = NetworkCacheConfiguration(
        memoryCapacity: 10 * 1024 * 1024,       // 10MB
        diskCapacity: 100 * 1024 * 1024,        // 100MB
        defaultTTL: 5 * 60                      // 5 minutes
    )
}
