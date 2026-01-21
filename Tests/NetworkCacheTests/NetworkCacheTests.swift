import XCTest
@testable import NetworkCache

final class NetworkCacheTests: XCTestCase {
    var cache: NetworkCache!
    
    override func setUp() async throws {
        // Create a fresh cache with test configuration
        cache = NetworkCache(configuration: NetworkCacheConfiguration(
            memoryCapacity: 1024 * 1024,  // 1MB
            diskCapacity: 10 * 1024 * 1024, // 10MB
            defaultTTL: 60, // 1 minute
            cleanupInterval: 3600,
            diskCacheDirectory: "com.networkcache.test"
        ))
        
        // Clear any existing cache
        try await cache.clear()
    }
    
    override func tearDown() async throws {
        try await cache.clear()
    }
    
    // MARK: - Basic Cache Operations
    
    func testSetAndGet() async throws {
        let key = CacheKey(url: "https://api.example.com/test", method: .get)
        let data = "Hello, World!".data(using: .utf8)!
        
        // Set data
        try await cache.set(data, for: key, ttl: 60)
        
        // Get data
        let retrieved = try await cache.get(key: key)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, data)
    }
    
    func testCacheMiss() async throws {
        let key = CacheKey(url: "https://api.example.com/nonexistent", method: .get)
        
        let retrieved = try await cache.get(key: key)
        XCTAssertNil(retrieved)
    }
    
    func testRemove() async throws {
        let key = CacheKey(url: "https://api.example.com/test", method: .get)
        let data = "Test data".data(using: .utf8)!
        
        // Set and verify
        try await cache.set(data, for: key)
        let afterSet = try await cache.get(key: key)
        XCTAssertNotNil(afterSet)
        
        // Remove and verify
        try await cache.remove(key: key)
        let afterRemove = try await cache.get(key: key)
        XCTAssertNil(afterRemove)
    }
    
    func testClear() async throws {
        let key1 = CacheKey(url: "https://api.example.com/test1", method: .get)
        let key2 = CacheKey(url: "https://api.example.com/test2", method: .get)
        let data = "Test data".data(using: .utf8)!
        
        // Set multiple entries
        try await cache.set(data, for: key1)
        try await cache.set(data, for: key2)
        
        // Clear all
        try await cache.clear()
        
        // Verify all removed
        let result1 = try await cache.get(key: key1)
        let result2 = try await cache.get(key: key2)
        XCTAssertNil(result1)
        XCTAssertNil(result2)
    }
    
    func testContains() async throws {
        let key = CacheKey(url: "https://api.example.com/test", method: .get)
        let data = "Test data".data(using: .utf8)!
        
        // Initially should not exist
        let initiallyContains = await cache.contains(key: key)
        XCTAssertFalse(initiallyContains)
        
        // Set data
        try await cache.set(data, for: key)
        
        // Should now exist
        let nowContains = await cache.contains(key: key)
        XCTAssertTrue(nowContains)
    }
    
    // MARK: - TTL and Expiration
    
    func testExpiration() async throws {
        let key = CacheKey(url: "https://api.example.com/test", method: .get)
        let data = "Test data".data(using: .utf8)!
        
        // Set with very short TTL
        try await cache.set(data, for: key, ttl: 0.1) // 100ms
        
        // Should be available immediately
        let immediate = try await cache.get(key: key)
        XCTAssertNotNil(immediate)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Should be expired and return nil
        let expired = try await cache.get(key: key)
        XCTAssertNil(expired)
    }
    
    // MARK: - Cache Key
    
    func testCacheKeyWithHeaders() {
        let key1 = CacheKey(url: "https://api.example.com/test", method: .get, headers: ["Authorization": "Bearer token1"])
        let key2 = CacheKey(url: "https://api.example.com/test", method: .get, headers: ["Authorization": "Bearer token2"])
        
        // Keys should be different due to different auth tokens
        XCTAssertNotEqual(key1.hashedValue, key2.hashedValue)
    }
    
    func testCacheKeyWithoutHeaders() {
        let key1 = CacheKey(url: "https://api.example.com/test", method: .get)
        let key2 = CacheKey(url: "https://api.example.com/test", method: .get)
        
        // Keys should be the same
        XCTAssertEqual(key1.hashedValue, key2.hashedValue)
    }
    
    func testCacheKeyDifferentMethods() {
        let key1 = CacheKey(url: "https://api.example.com/test", method: .get)
        let key2 = CacheKey(url: "https://api.example.com/test", method: .post)
        
        // Keys should be different
        XCTAssertNotEqual(key1.hashedValue, key2.hashedValue)
    }
    
    // MARK: - Statistics
    
    func testStatistics() async throws {
        let key = CacheKey(url: "https://api.example.com/test", method: .get)
        let data = "Test data".data(using: .utf8)!
        
        // Get initial statistics
        var stats = await cache.statistics()
        let initialHits = stats.hits
        let initialMisses = stats.misses
        
        // Cache miss
        _ = try await cache.get(key: key)
        stats = await cache.statistics()
        XCTAssertEqual(stats.misses, initialMisses + 1)
        
        // Set data
        try await cache.set(data, for: key)
        
        // Cache hit
        _ = try await cache.get(key: key)
        stats = await cache.statistics()
        XCTAssertEqual(stats.hits, initialHits + 1)
    }
    
    // MARK: - Configuration
    
    func testCustomConfiguration() {
        let config = NetworkCacheConfiguration(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 1024 * 1024 * 1024,
            defaultTTL: 3600,
            offlineModeEnabled: true,
            maxStaleAge: 86400
        )
        
        XCTAssertEqual(config.memoryCapacity, 100 * 1024 * 1024)
        XCTAssertEqual(config.diskCapacity, 1024 * 1024 * 1024)
        XCTAssertEqual(config.defaultTTL, 3600)
        XCTAssertTrue(config.offlineModeEnabled)
        XCTAssertEqual(config.maxStaleAge, 86400)
    }
    
    func testDefaultConfiguration() {
        let config = NetworkCacheConfiguration.default
        
        XCTAssertEqual(config.memoryCapacity, 50 * 1024 * 1024)
        XCTAssertEqual(config.diskCapacity, 500 * 1024 * 1024)
        XCTAssertEqual(config.defaultTTL, 24 * 60 * 60)
    }
}
