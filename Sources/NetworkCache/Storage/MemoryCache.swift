import Foundation

/// Thread-safe in-memory cache using NSCache with LRU tracking
actor MemoryCache {
    private let cache: NSCache<NSString, CacheEntryWrapper>
    private let capacity: Int
    private var accessLog: [String: Date] = [:]
    
    /// Wrapper class for storing CacheEntry in NSCache
    private class CacheEntryWrapper {
        let entry: CacheEntry
        
        init(entry: CacheEntry) {
            self.entry = entry
        }
    }
    
    init(capacity: Int) {
        self.capacity = capacity
        self.cache = NSCache<NSString, CacheEntryWrapper>()
        self.cache.totalCostLimit = capacity
        
        // Set delegate to track evictions
        self.cache.name = "com.networkcache.memory"
    }
    
    /// Store an entry in memory cache
    func set(_ entry: CacheEntry, for key: CacheKey) {
        let nsKey = key.hashedValue as NSString
        let wrapper = CacheEntryWrapper(entry: entry)
        
        // Use entry size as cost for NSCache
        cache.setObject(wrapper, forKey: nsKey, cost: entry.size)
        accessLog[key.hashedValue] = Date()
    }
    
    /// Retrieve an entry from memory cache
    func get(for key: CacheKey) -> CacheEntry? {
        let nsKey = key.hashedValue as NSString
        
        guard let wrapper = cache.object(forKey: nsKey) else {
            return nil
        }
        
        // Update access time for LRU
        accessLog[key.hashedValue] = Date()
        
        // Return entry with updated access time
        return wrapper.entry.accessed()
    }
    
    /// Check if an entry exists in memory cache
    func contains(key: CacheKey) -> Bool {
        let nsKey = key.hashedValue as NSString
        return cache.object(forKey: nsKey) != nil
    }
    
    /// Remove an entry from memory cache
    func remove(for key: CacheKey) {
        let nsKey = key.hashedValue as NSString
        cache.removeObject(forKey: nsKey)
        accessLog.removeValue(forKey: key.hashedValue)
    }
    
    /// Clear all entries from memory cache
    func removeAll() {
        cache.removeAllObjects()
        accessLog.removeAll()
    }
    
    /// Get current memory usage and entry count
    func getStatistics() -> (entryCount: Int, estimatedSize: Int) {
        // NSCache doesn't provide direct access to all objects
        // We track this through access log
        let entryCount = accessLog.count
        
        // Estimate size based on entries (actual size managed by NSCache)
        let estimatedSize = entryCount > 0 ? capacity / 10 : 0
        
        return (entryCount, estimatedSize)
    }
    
    /// Get least recently used keys for eviction
    func getLRUKeys(count: Int) -> [String] {
        let sortedByAccess = accessLog.sorted { $0.value < $1.value }
        return Array(sortedByAccess.prefix(count).map { $0.key })
    }
    
    /// Remove expired entries
    func removeExpiredEntries() -> Int {
        var removedCount = 0
        let now = Date()
        
        // Collect keys to remove (can't modify while iterating)
        var keysToRemove: [String] = []
        
        for (keyHash, _) in accessLog {
            let nsKey = keyHash as NSString
            if let wrapper = cache.object(forKey: nsKey),
               wrapper.entry.isExpired(at: now) {
                keysToRemove.append(keyHash)
            }
        }
        
        // Remove expired entries
        for keyHash in keysToRemove {
            let nsKey = keyHash as NSString
            cache.removeObject(forKey: nsKey)
            accessLog.removeValue(forKey: keyHash)
            removedCount += 1
        }
        
        return removedCount
    }
}
