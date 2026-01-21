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

## Quick Start

```swift
import NetworkCache

let cache = NetworkCache.shared
let key = CacheKey(url: "https://api.example.com/data", method: .get)

// Check cache first
if let cachedData = try await cache.get(key: key) {
    print("From cache!")
} else {
    // Fetch and cache
    let data = try await fetchFromNetwork()
    try await cache.set(data, for: key, ttl: 3600)
}
```

## Documentation

Full documentation is available in [NetworkCache/README.md](NetworkCache/README.md).

## Installation

Add this package to your project using Swift Package Manager.

## License

MIT License - See LICENSE file for details.