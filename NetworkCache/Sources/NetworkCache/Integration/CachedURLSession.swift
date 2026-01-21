import Foundation

/// Optional URLSession wrapper with automatic caching
public class CachedURLSession {
    private let cache: NetworkCache
    private let session: URLSession
    private let respectHTTPHeaders: Bool
    
    /// Create a cached URLSession wrapper
    /// - Parameters:
    ///   - cache: The NetworkCache instance to use (defaults to shared)
    ///   - session: The underlying URLSession (defaults to shared)
    ///   - respectHTTPHeaders: Whether to respect HTTP cache headers (default: true)
    public init(
        cache: NetworkCache = .shared,
        session: URLSession = .shared,
        respectHTTPHeaders: Bool = true
    ) {
        self.cache = cache
        self.session = session
        self.respectHTTPHeaders = respectHTTPHeaders
    }
    
    /// Perform a data task with automatic caching
    /// - Parameters:
    ///   - request: The URL request
    ///   - forceRefresh: If true, bypasses cache and fetches from network
    /// - Returns: Data and response tuple
    public func data(for request: URLRequest, forceRefresh: Bool = false) async throws -> (Data, URLResponse) {
        guard let url = request.url?.absoluteString else {
            throw NetworkCacheError.invalidKey
        }
        
        let method = request.httpMethod ?? "GET"
        let headers = request.allHTTPHeaderFields
        
        let cacheKey = CacheKey(url: url, method: method, headers: headers)
        
        // Check cache first (unless force refresh)
        if !forceRefresh, let cachedData = try await cache.get(key: cacheKey) {
            // Create a fake response for cached data
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["X-Cache": "HIT"]
            )!
            return (cachedData, response)
        }
        
        // Fetch from network
        let (data, response) = try await session.data(for: request)
        
        // Determine TTL from HTTP headers if respecting them
        var ttl: TimeInterval? = nil
        if respectHTTPHeaders, let httpResponse = response as? HTTPURLResponse {
            ttl = parseCacheTTL(from: httpResponse)
        }
        
        // Cache the response
        try await cache.set(data, for: cacheKey, ttl: ttl)
        
        return (data, response)
    }
    
    /// Perform a data task with URL
    /// - Parameters:
    ///   - url: The URL
    ///   - forceRefresh: If true, bypasses cache and fetches from network
    /// - Returns: Data and response tuple
    public func data(from url: URL, forceRefresh: Bool = false) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url), forceRefresh: forceRefresh)
    }
    
    // MARK: - Private Helpers
    
    /// Parse cache TTL from HTTP headers (Cache-Control, Expires)
    private func parseCacheTTL(from response: HTTPURLResponse) -> TimeInterval? {
        // Check Cache-Control header
        if let cacheControl = response.value(forHTTPHeaderField: "Cache-Control") {
            // Look for max-age directive
            let components = cacheControl.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for component in components {
                if component.hasPrefix("max-age=") {
                    let maxAgeString = component.replacingOccurrences(of: "max-age=", with: "")
                    if let maxAge = TimeInterval(maxAgeString) {
                        return maxAge
                    }
                }
                
                // Check for no-cache or no-store
                if component == "no-cache" || component == "no-store" {
                    return nil // Don't cache
                }
            }
        }
        
        // Check Expires header
        if let expiresString = response.value(forHTTPHeaderField: "Expires") {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let expiresDate = dateFormatter.date(from: expiresString) {
                let ttl = expiresDate.timeIntervalSinceNow
                return max(0, ttl) // Don't return negative TTL
            }
        }
        
        // No cache headers found, use default from configuration
        return nil
    }
}

// MARK: - Convenience Extensions

extension CachedURLSession {
    /// Download and decode a Codable type with automatic caching
    /// - Parameters:
    ///   - type: The Codable type to decode
    ///   - request: The URL request
    ///   - forceRefresh: If true, bypasses cache and fetches from network
    ///   - decoder: The JSONDecoder to use (defaults to standard)
    /// - Returns: Decoded object
    public func decodable<T: Decodable>(
        _ type: T.Type,
        for request: URLRequest,
        forceRefresh: Bool = false,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let (data, _) = try await data(for: request, forceRefresh: forceRefresh)
        return try decoder.decode(type, from: data)
    }
    
    /// Download and decode a Codable type from URL with automatic caching
    /// - Parameters:
    ///   - type: The Codable type to decode
    ///   - url: The URL
    ///   - forceRefresh: If true, bypasses cache and fetches from network
    ///   - decoder: The JSONDecoder to use (defaults to standard)
    /// - Returns: Decoded object
    public func decodable<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        forceRefresh: Bool = false,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        try await decodable(type, for: URLRequest(url: url), forceRefresh: forceRefresh, decoder: decoder)
    }
}
