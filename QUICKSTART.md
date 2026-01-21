# NetworkCache Quick Start Guide

Get started with NetworkCache in under 5 minutes!

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/m00nbek/network-cache.git", from: "1.0.0")
]
```

Or add in Xcode: **File → Add Package Dependencies**

## Basic Usage (3 Steps)

### Step 1: Import the Package

```swift
import NetworkCache
```

### Step 2: Create Cache Keys

```swift
let cacheKey = CacheKey(
    url: "https://api.example.com/data",
    method: .get,
    headers: ["Authorization": "Bearer token"]
)
```

### Step 3: Use the Cache

```swift
// Check cache first
if let cachedData = try await NetworkCache.shared.get(key: cacheKey) {
    print("From cache!")
    return try JSONDecoder().decode(MyModel.self, from: cachedData)
}

// Fetch from network
let data = try await fetchFromNetwork()

// Store in cache
try await NetworkCache.shared.set(data, for: cacheKey, ttl: 3600)
```

## Integration with Existing Code

### Before (Without Cache)

```swift
func getSemesters() async throws -> [Semester] {
    guard let token = AppCore.shared.token else { throw AppError.unauthorized }
    
    let response = try await AlamofireClient().task(
        URLs.semesters,
        method: .post,
        headers: ["authorization": token]
    )
    
    let semesters: [SemesterDTO] = try ValidationWrapper.validate(response: response)
    return semesters.map { $0.model }
}
```

### After (With Cache) - Just 5 Lines Added!

```swift
func getSemesters(forceRefresh: Bool = false) async throws -> [Semester] {
    guard let token = AppCore.shared.token else { throw AppError.unauthorized }
    
    // ✅ NEW: Create cache key
    let cacheKey = CacheKey(url: URLs.semesters, method: .post, headers: ["authorization": token])
    
    // ✅ NEW: Check cache first
    if !forceRefresh, let cachedData = try await NetworkCache.shared.get(key: cacheKey) {
        let semesters: [SemesterDTO] = try JSONDecoder().decode([SemesterDTO].self, from: cachedData)
        return semesters.map { $0.model }
    }
    
    let response = try await AlamofireClient().task(
        URLs.semesters,
        method: .post,
        headers: ["authorization": token]
    )
    
    let semesters: [SemesterDTO] = try ValidationWrapper.validate(response: response)
    
    // ✅ NEW: Cache the response
    if let responseData = response.data {
        try await NetworkCache.shared.set(responseData, for: cacheKey, ttl: 3600)
    }
    
    return semesters.map { $0.model }
}
```

## Configuration

### Use Default Configuration

```swift
let cache = NetworkCache.shared
```

### Customize Configuration

```swift
let config = NetworkCacheConfiguration(
    memoryCapacity: 100 * 1024 * 1024,  // 100MB
    diskCapacity: 1024 * 1024 * 1024,   // 1GB
    defaultTTL: 3600,                    // 1 hour
    offlineModeEnabled: true             // Serve stale cache when offline
)

let cache = NetworkCache(configuration: config)
```

## Common Patterns

### Pattern 1: Force Refresh (Pull-to-Refresh)

```swift
// Normal: uses cache
let data = try await fetchData()

// Force refresh: bypasses cache
let freshData = try await fetchData(forceRefresh: true)
```

### Pattern 2: Different TTL for Different Data

```swift
// User data: 15 minutes
try await cache.set(userData, for: userKey, ttl: 15 * 60)

// Static data: 24 hours
try await cache.set(staticData, for: staticKey, ttl: 24 * 60 * 60)

// Live data: 30 seconds
try await cache.set(liveData, for: liveKey, ttl: 30)
```

### Pattern 3: Cache Statistics

```swift
let stats = await cache.statistics()
print("Hit rate: \(stats.hitRate)%")
print("Cache size: \(stats.totalSize) bytes")
```

### Pattern 4: Clear Cache

```swift
// Clear specific entry
try await cache.remove(key: cacheKey)

// Clear all cache
try await cache.clear()
```

## Key Features

✅ **Networking Library Agnostic** - Works with Alamofire, URLSession, or any HTTP client  
✅ **Two-Layer Caching** - Fast memory + persistent disk storage  
✅ **Offline Mode** - Automatically serves stale cache when offline  
✅ **TTL & LRU** - Flexible expiration policies  
✅ **Thread-Safe** - Built with Swift Concurrency  
✅ **Zero Dependencies** - Pure Swift, no external dependencies  

## Need Help?

- 📖 Full documentation: [README.md](README.md)
- 💡 Examples: [Examples/](Examples/)
- 🧪 Tests: [Tests/NetworkCacheTests/](Tests/NetworkCacheTests/)

## Next Steps

1. ✅ Install the package
2. ✅ Add 5 lines to your existing network calls
3. ✅ Test with force refresh
4. ✅ Monitor cache statistics
5. ✅ Configure TTL based on your data types

That's it! You're ready to go 🚀
