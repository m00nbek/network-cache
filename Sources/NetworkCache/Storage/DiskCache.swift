import Foundation

/// Thread-safe disk-based cache with file storage
actor DiskCache {
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let capacity: Int
    private var currentSize: Int = 0
    private var entries: [String: CacheEntry] = [:]
    
    init(directory: String, capacity: Int) throws {
        self.fileManager = FileManager.default
        self.capacity = capacity
        
        // Get cache directory URL
        guard let cacheBaseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NetworkCacheError.directoryCreationFailed(
                NSError(domain: "NetworkCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not access caches directory"])
            )
        }
        
        self.cacheDirectory = cacheBaseURL.appendingPathComponent(directory, isDirectory: true)
        
        // Create directory if needed (synchronously in init)
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                throw NetworkCacheError.directoryCreationFailed(error)
            }
        }
        
        // Load existing entries metadata (synchronously in init)
        // Note: Must be done synchronously in init, so we can't use actor isolation here
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            for fileURL in fileURLs {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let entry = try JSONDecoder().decode(CacheEntry.self, from: data)
                    let keyHash = fileURL.deletingPathExtension().lastPathComponent
                    entries[keyHash] = entry
                    currentSize += entry.size
                } catch {
                    // Skip corrupted files
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            // Directory might be empty or inaccessible
        }
    }
    
    private func fileURL(for key: CacheKey) -> URL {
        cacheDirectory.appendingPathComponent("\(key.hashedValue).cache")
    }
    
    /// Store an entry on disk
    func set(_ entry: CacheEntry, for key: CacheKey) throws {
        let fileURL = fileURL(for: key)
        
        // Encode entry
        let data: Data
        do {
            data = try JSONEncoder().encode(entry)
        } catch {
            throw NetworkCacheError.encodingFailed(error)
        }
        
        // Check if we need to evict entries to make space
        let newEntrySize = entry.size
        if currentSize + newEntrySize > capacity {
            try evictLRUEntries(toFree: newEntrySize)
        }
        
        // Write atomically
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw NetworkCacheError.diskWriteFailed(error)
        }
        
        // Update metadata
        if let existingEntry = entries[key.hashedValue] {
            currentSize -= existingEntry.size
        }
        entries[key.hashedValue] = entry
        currentSize += entry.size
    }
    
    /// Retrieve an entry from disk
    func get(for key: CacheKey) throws -> CacheEntry? {
        let fileURL = fileURL(for: key)
        
        // Check if file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Read file
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw NetworkCacheError.diskReadFailed(error)
        }
        
        // Decode entry
        let entry: CacheEntry
        do {
            entry = try JSONDecoder().decode(CacheEntry.self, from: data)
        } catch {
            // Remove corrupted file
            try? fileManager.removeItem(at: fileURL)
            throw NetworkCacheError.decodingFailed(error)
        }
        
        // Update last accessed time
        let updatedEntry = entry.accessed()
        
        // Update metadata
        entries[key.hashedValue] = updatedEntry
        
        // Write back with updated access time (async, don't wait)
        Task {
            try? set(updatedEntry, for: key)
        }
        
        return updatedEntry
    }
    
    /// Check if an entry exists on disk
    func contains(key: CacheKey) -> Bool {
        entries[key.hashedValue] != nil
    }
    
    /// Remove an entry from disk
    func remove(for key: CacheKey) throws {
        let fileURL = fileURL(for: key)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                throw NetworkCacheError.diskWriteFailed(error)
            }
        }
        
        // Update metadata
        if let entry = entries[key.hashedValue] {
            currentSize -= entry.size
            entries.removeValue(forKey: key.hashedValue)
        }
    }
    
    /// Clear all entries from disk
    func removeAll() throws {
        // Remove all files
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in fileURLs {
                try? fileManager.removeItem(at: fileURL)
            }
        } catch {
            throw NetworkCacheError.diskWriteFailed(error)
        }
        
        // Clear metadata
        entries.removeAll()
        currentSize = 0
    }
    
    /// Get current disk usage and entry count
    func getStatistics() -> (entryCount: Int, size: Int) {
        (entries.count, currentSize)
    }
    
    /// Remove expired entries
    func removeExpiredEntries() -> Int {
        var removedCount = 0
        let now = Date()
        
        let expiredKeys = entries.filter { $0.value.isExpired(at: now) }.map { $0.key }
        
        for keyHash in expiredKeys {
            // Reconstruct the key for removal
            let fileURL = cacheDirectory.appendingPathComponent("\(keyHash).cache")
            try? fileManager.removeItem(at: fileURL)
            
            if let entry = entries[keyHash] {
                currentSize -= entry.size
                entries.removeValue(forKey: keyHash)
                removedCount += 1
            }
        }
        
        return removedCount
    }
    
    /// Evict least recently used entries to free up space
    private func evictLRUEntries(toFree requiredSpace: Int) throws {
        var freedSpace = 0
        
        // Sort by last accessed time (oldest first)
        let sortedEntries = entries.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
        
        for (keyHash, entry) in sortedEntries {
            if freedSpace >= requiredSpace {
                break
            }
            
            // Remove file
            let fileURL = cacheDirectory.appendingPathComponent("\(keyHash).cache")
            try? fileManager.removeItem(at: fileURL)
            
            // Update metadata
            currentSize -= entry.size
            entries.removeValue(forKey: keyHash)
            freedSpace += entry.size
        }
        
        // If we couldn't free enough space, throw error
        if freedSpace < requiredSpace {
            throw NetworkCacheError.cacheFull
        }
    }
    
    /// Get all cache keys with stale entries (for offline mode)
    func getStaleEntries(maxStaleAge: TimeInterval) -> [String: CacheEntry] {
        let now = Date()
        return entries.filter { keyHash, entry in
            entry.isStale(maxStaleAge: maxStaleAge, at: now)
        }
    }
}
