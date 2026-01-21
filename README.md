# NetworkCache

A Swift package for efficient network response caching with memory and disk storage, designed for iOS projects.

## Features

- 🚀 **Networking Library Agnostic** - Works with Alamofire, URLSession, or any HTTP client
- 💾 **Two-Layer Caching** - Fast in-memory cache backed by persistent disk storage
- ⏱️ **Flexible Expiration** - TTL-based expiration with LRU eviction
- 📴 **Offline Mode** - Serve stale cache when network is unavailable
- 🔒 **Thread-Safe** - Built with Swift Concurrency (async/await) and actor isolation
- 📊 **Cache Statistics** - Track hit rates and cache performance
- 🎯 **Simple API** - Clean, minimal API with sensible defaults

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 6.1+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/network-cache.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File > Add Package Dependencies
2. Enter the repository URL
3. Select your desired version

## Quick Start

### Basic Usage

```swift
import NetworkCache

// Use the shared instance
let cache = NetworkCache.shared

// Create a cache key
let key = CacheKey(
    url: "https://api.example.com/data",
    method: .get,
    headers: ["Authorization": "Bearer token"]
)

// Check cache first
if let cachedData = try await cache.get(key: key) {
    // Use cached data
    let model = try JSONDecoder().decode(MyModel.self, from: cachedData)
    print("From cache!")
} else {
    // Fetch from network and cache
    let data = try await fetchFromNetwork()
    try await cache.set(data, for: key, ttl: 3600) // Cache for 1 hour
}
```

## Integration Examples

### With Alamofire (Recommended Pattern)

Here's how to integrate NetworkCache into your existing Alamofire-based service layer:

```swift
import Foundation
import HTTPClient
import NetworkCache

final class ModuleService {
    private let cache = NetworkCache.shared
    
    func getSemesters(forceRefresh: Bool = false) async throws -> [Semester] {
        guard let token = AppCore.shared.token else { 
            throw AppError.unauthorized 
        }
        
        let url = URLs.semesters
        let headers: [String: String] = ["authorization": token]
        
        // Create cache key
        let cacheKey = CacheKey(url: url, method: .post, headers: headers)
        
        // Check cache first (unless force refresh)
        if !forceRefresh, let cachedData = try await cache.get(key: cacheKey) {
            // Decode from cache
            let semesters: [SemesterDTO] = try JSONDecoder().decode([SemesterDTO].self, from: cachedData)
            return semesters.map { $0.model }
        }
        
        // Fetch from network
        let response = try await AlamofireClient().task(
            url,
            method: .post,
            parameters: [:],
            encoding: .url,
            headers: headers
        )
        
        // Validate and parse
        let semesters: [SemesterDTO] = try ValidationWrapper.validate(response: response)
        
        // Cache the raw response data for future use
        if let responseData = response.data {
            try await cache.set(responseData, for: cacheKey, ttl: 3600) // Cache for 1 hour
        }
        
        return semesters.map { $0.model }
    }
}
```

**Key Benefits:**
- ✅ Only 5 lines added to your existing code
- ✅ Full control over when to cache vs. fetch fresh
- ✅ Works with your existing validation pipeline
- ✅ Auth tokens included in cache keys (different users don't share cache)

### With URLSession (Optional Wrapper)

For projects using URLSession, use the convenient wrapper:

```swift
import NetworkCache

let session = CachedURLSession()

// Simple data fetch with automatic caching
let (data, response) = try await session.data(from: url)

// Or with URLRequest
let request = URLRequest(url: url)
let (data, response) = try await session.data(for: request)

// Force refresh (bypass cache)
let (freshData, _) = try await session.data(from: url, forceRefresh: true)

// Decode directly
let users: [User] = try await session.decodable([User].self, from: url)
```

## Configuration

### Using Predefined Configurations

```swift
// Default configuration (50MB memory, 500MB disk, 24h TTL)
let cache = NetworkCache(configuration: .default)

// Aggressive caching (100MB memory, 1GB disk, 7 days TTL)
let cache = NetworkCache(configuration: .aggressive)

// Conservative caching (10MB memory, 100MB disk, 5 min TTL)
let cache = NetworkCache(configuration: .conservative)
```

### Custom Configuration

```swift
let config = NetworkCacheConfiguration(
    memoryCapacity: 50 * 1024 * 1024,        // 50MB
    diskCapacity: 500 * 1024 * 1024,          // 500MB
    defaultTTL: 3600,                         // 1 hour
    cleanupInterval: 3600,                    // Cleanup every hour
    offlineModeEnabled: true,                 // Enable offline mode
    maxStaleAge: 86400,                       // Serve cache up to 24h old when offline
    diskCacheDirectory: "com.myapp.cache",    // Custom cache directory
    lruEvictionEnabled: true,                 // Enable LRU eviction
    debugLogging: false                       // Disable debug logs
)

let cache = NetworkCache(configuration: config)
```

## Advanced Features

### Offline Mode

Enable offline mode to automatically serve stale cache when the network is unavailable:

```swift
let config = NetworkCacheConfiguration(
    offlineModeEnabled: true,
    maxStaleAge: 86400  // Serve cache up to 24 hours old when offline
)
let cache = NetworkCache(configuration: config)

// When offline, the cache will automatically serve stale data
// No code changes needed in your service layer!
```

### Cache Statistics

Monitor cache performance:

```swift
let stats = await cache.statistics()

print("Cache hit rate: \(stats.hitRate)%")
print("Total size: \(stats.totalSize) bytes")
print("Memory entries: \(stats.memoryEntryCount)")
print("Disk entries: \(stats.diskEntryCount)")
print("Hits: \(stats.hits), Misses: \(stats.misses)")
```

### TTL Strategies

Different data types need different cache durations:

```swift
// User-specific data (shorter TTL)
try await cache.set(userData, for: userKey, ttl: 15 * 60)  // 15 minutes

// Static/reference data (longer TTL)
try await cache.set(staticData, for: staticKey, ttl: 24 * 60 * 60)  // 24 hours

// Temporary data (very short TTL)
try await cache.set(tempData, for: tempKey, ttl: 60)  // 1 minute

// Use default TTL from configuration
try await cache.set(data, for: key)  // Uses config.defaultTTL
```

### Force Refresh Pattern

Implement pull-to-refresh:

```swift
func fetchData(forceRefresh: Bool = false) async throws -> [Item] {
    let key = CacheKey(url: apiURL, method: .get)
    
    if !forceRefresh, let cachedData = try await cache.get(key: key) {
        return try JSONDecoder().decode([Item].self, from: cachedData)
    }
    
    // Fetch fresh data...
    let data = try await networkFetch()
    try await cache.set(data, for: key)
    return try JSONDecoder().decode([Item].self, from: data)
}

// Normal fetch (uses cache)
let items = try await fetchData()

// Pull-to-refresh (bypasses cache)
let freshItems = try await fetchData(forceRefresh: true)
```

### Cache Key with Selective Headers

Include only specific headers in the cache key:

```swift
let key = CacheKey(
    url: url,
    method: .get,
    selectiveHeaders: allHeaders,
    include: ["Authorization", "Accept-Language"]  // Only these headers affect the key
)
```

### Manual Cache Management

```swift
// Check if cached
let isCached = await cache.contains(key: key)

// Remove specific entry
try await cache.remove(key: key)

// Clear all cache
try await cache.clear()
```

## API Reference

### NetworkCache

#### Main Methods

- `get(key: CacheKey) async throws -> Data?` - Retrieve cached data
- `set(_ data: Data, for key: CacheKey, ttl: TimeInterval?) async throws` - Store data
- `remove(key: CacheKey) async throws` - Remove specific entry
- `clear() async throws` - Clear all cache
- `contains(key: CacheKey) async -> Bool` - Check if key exists
- `statistics() async -> CacheStatistics` - Get cache statistics

### CacheKey

Create cache keys for identifying cached entries:

```swift
CacheKey(url: String, method: String, headers: [String: String]?)
CacheKey(url: String, method: HTTPMethod, headers: [String: String]?)
CacheKey(url: String, method: String, selectiveHeaders: [String: String]?, include: [String])
```

### NetworkCacheConfiguration

Configure cache behavior:

- `memoryCapacity: Int` - Maximum memory cache size in bytes
- `diskCapacity: Int` - Maximum disk cache size in bytes
- `defaultTTL: TimeInterval` - Default time-to-live for entries
- `cleanupInterval: TimeInterval` - Automatic cleanup interval
- `offlineModeEnabled: Bool` - Enable offline mode
- `maxStaleAge: TimeInterval` - Maximum age for stale entries in offline mode
- `lruEvictionEnabled: Bool` - Enable LRU eviction
- `debugLogging: Bool` - Enable debug logging

## Best Practices

### 1. Include Auth Tokens in Cache Keys

```swift
// ✅ Good - Different users get different cache
let key = CacheKey(
    url: url,
    method: .post,
    headers: ["authorization": token]
)

// ❌ Bad - All users share the same cache
let key = CacheKey(url: url, method: .post)
```

### 2. Cache After Validation

```swift
// ✅ Good - Only cache valid responses
let response = try await AlamofireClient().task(...)
let data: [DTO] = try ValidationWrapper.validate(response: response)
if let responseData = response.data {
    try await cache.set(responseData, for: key)
}

// ❌ Bad - Caching before validation
let response = try await AlamofireClient().task(...)
try await cache.set(response.data, for: key)  // Might cache errors!
let data = try ValidationWrapper.validate(response: response)
```

### 3. Use Appropriate TTL Values

```swift
// User-specific, frequently changing data
try await cache.set(data, for: key, ttl: 15 * 60)  // 15 minutes

// Static/reference data
try await cache.set(data, for: key, ttl: 24 * 60 * 60)  // 24 hours

// Real-time data
try await cache.set(data, for: key, ttl: 30)  // 30 seconds
```

### 4. Implement Force Refresh

Always provide a way to bypass cache:

```swift
func fetchData(forceRefresh: Bool = false) async throws -> Data {
    let key = CacheKey(url: url, method: .get)
    
    if !forceRefresh, let cached = try await cache.get(key: key) {
        return cached
    }
    
    // Fetch fresh data...
}
```

## Performance

- **Memory cache** provides instant access (< 1ms)
- **Disk cache** typically responds in 1-5ms
- **Automatic cleanup** runs in background without blocking
- **LRU eviction** ensures most frequently used data stays cached
- **Actor isolation** ensures thread-safety without lock contention

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, questions, or feature requests, please open an issue on GitHub.
