import Foundation
import CryptoKit

/// Represents a cache key for identifying cached entries
public struct CacheKey: Hashable, Codable, Sendable {
    /// The raw key string
    public let value: String
    
    /// HTTP method (GET, POST, etc.)
    public let method: String
    
    /// URL string
    public let url: String
    
    /// Relevant headers included in the key
    public let headers: [String: String]
    
    /// Create a cache key from components
    public init(url: String, method: String = "GET", headers: [String: String]? = nil) {
        self.url = url
        self.method = method.uppercased()
        self.headers = headers ?? [:]
        
        // Generate the key value
        var components: [String] = [self.method, url]
        
        // Add sorted headers for consistent key generation
        let sortedHeaders = (headers ?? [:]).sorted { $0.key < $1.key }
        for (key, value) in sortedHeaders {
            components.append("\(key):\(value)")
        }
        
        self.value = components.joined(separator: "|")
    }
    
    /// Create a cache key with selective headers (only include specific headers)
    public init(url: String, method: String = "GET", selectiveHeaders: [String: String]?, include headerKeys: [String]) {
        let filteredHeaders = selectiveHeaders?.filter { headerKeys.contains($0.key) }
        self.init(url: url, method: method, headers: filteredHeaders)
    }
    
    /// Generate a secure hash of the key for use as filename
    public var hashedValue: String {
        let data = Data(value.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Human-readable description for debugging
    public var debugDescription: String {
        var desc = "\(method) \(url)"
        if !headers.isEmpty {
            let headerDesc = headers.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            desc += " [\(headerDesc)]"
        }
        return desc
    }
}

// MARK: - Convenience Extensions

extension CacheKey {
    /// Common HTTP methods
    public enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
        case head = "HEAD"
        case options = "OPTIONS"
    }
    
    /// Create a cache key with HTTPMethod enum
    public init(url: String, method: HTTPMethod, headers: [String: String]? = nil) {
        self.init(url: url, method: method.rawValue, headers: headers)
    }
}
