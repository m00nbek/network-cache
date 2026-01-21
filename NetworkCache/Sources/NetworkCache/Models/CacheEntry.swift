import Foundation

/// Represents a cached data entry with metadata for expiration and tracking
public struct CacheEntry: Codable, Sendable {
    /// The cached data
    public let data: Data
    
    /// When this entry was created
    public let createdAt: Date
    
    /// When this entry expires (nil means no expiration)
    public let expiresAt: Date?
    
    /// Last time this entry was accessed (for LRU tracking)
    public var lastAccessedAt: Date
    
    /// Size of the cached data in bytes
    public var size: Int {
        data.count
    }
    
    /// Optional HTTP metadata for debugging
    public let metadata: Metadata?
    
    public struct Metadata: Codable, Sendable {
        public let url: String
        public let statusCode: Int?
        public let headers: [String: String]?
        
        public init(url: String, statusCode: Int? = nil, headers: [String: String]? = nil) {
            self.url = url
            self.statusCode = statusCode
            self.headers = headers
        }
    }
    
    public init(
        data: Data,
        createdAt: Date = Date(),
        ttl: TimeInterval? = nil,
        metadata: Metadata? = nil
    ) {
        self.data = data
        self.createdAt = createdAt
        self.expiresAt = ttl.map { createdAt.addingTimeInterval($0) }
        self.lastAccessedAt = createdAt
        self.metadata = metadata
    }
    
    /// Check if this entry has expired
    public func isExpired(at date: Date = Date()) -> Bool {
        guard let expiresAt = expiresAt else { return false }
        return date >= expiresAt
    }
    
    /// Check if this entry is stale (expired but within tolerance for offline mode)
    public func isStale(maxStaleAge: TimeInterval, at date: Date = Date()) -> Bool {
        guard let expiresAt = expiresAt else { return false }
        let staleDeadline = expiresAt.addingTimeInterval(maxStaleAge)
        return date >= expiresAt && date < staleDeadline
    }
    
    /// Create a new entry with updated last accessed time
    public func accessed(at date: Date = Date()) -> CacheEntry {
        var entry = self
        entry.lastAccessedAt = date
        return entry
    }
}
