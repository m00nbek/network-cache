import Foundation

/// Statistics about cache performance and usage
public struct CacheStatistics: Sendable {
    /// Total number of cache hits
    public let hits: Int
    
    /// Total number of cache misses
    public let misses: Int
    
    /// Total size of cached data in memory (bytes)
    public let memorySize: Int
    
    /// Total size of cached data on disk (bytes)
    public let diskSize: Int
    
    /// Number of entries in memory cache
    public let memoryEntryCount: Int
    
    /// Number of entries in disk cache
    public let diskEntryCount: Int
    
    /// Cache hit rate as a percentage (0-100)
    public var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0.0 }
        return Double(hits) / Double(total) * 100.0
    }
    
    /// Total size of all cached data (memory + disk)
    public var totalSize: Int {
        memorySize + diskSize
    }
    
    /// Total number of entries (memory + disk)
    public var totalEntryCount: Int {
        memoryEntryCount + diskEntryCount
    }
    
    public init(
        hits: Int = 0,
        misses: Int = 0,
        memorySize: Int = 0,
        diskSize: Int = 0,
        memoryEntryCount: Int = 0,
        diskEntryCount: Int = 0
    ) {
        self.hits = hits
        self.misses = misses
        self.memorySize = memorySize
        self.diskSize = diskSize
        self.memoryEntryCount = memoryEntryCount
        self.diskEntryCount = diskEntryCount
    }
}
