import Foundation
import NetworkCache

// MARK: - Example Integration with Alamofire

/// This example shows how to integrate NetworkCache with your existing Alamofire-based service layer
/// Based on the ModuleService pattern

// Uncomment to use in a real project:
// import HTTPClient

final class ModuleService {
    private let cache = NetworkCache.shared
    
    /// Fetch semesters with optional caching
    /// - Parameter forceRefresh: If true, bypasses cache and fetches from network
    /// - Returns: Array of Semester models
    func getSemesters(forceRefresh: Bool = false) async throws -> [Semester] {
        // Get auth token (replace with your auth mechanism)
        guard let token = AppCore.shared.token else { 
            throw AppError.unauthorized 
        }
        
        let url = URLs.semesters
        let headers: [String: String] = ["authorization": token]
        
        // Create cache key (includes auth token so different users don't share cache)
        let cacheKey = CacheKey(url: url, method: .post, headers: headers)
        
        // Check cache first (unless force refresh)
        if !forceRefresh, let cachedData = try await cache.get(key: cacheKey) {
            // Decode from cache
            let semesters: [SemesterDTO] = try JSONDecoder().decode([SemesterDTO].self, from: cachedData)
            print("✅ Loaded semesters from cache")
            return semesters.map { $0.model }
        }
        
        print("🌐 Fetching semesters from network")
        
        // Fetch from network
        // Replace with your actual Alamofire call:
        let response = try await fetchFromNetwork(url: url, headers: headers)
        
        // Validate and parse (using your existing validation)
        // let semesters: [SemesterDTO] = try ValidationWrapper.validate(response: response)
        
        // For this example, decode directly:
        let semesters: [SemesterDTO] = try JSONDecoder().decode([SemesterDTO].self, from: response)
        
        // Cache the raw response data for future use
        try await cache.set(response, for: cacheKey, ttl: 3600) // Cache for 1 hour
        
        return semesters.map { $0.model }
    }
    
    /// Fetch user profile with different TTL strategy
    func getUserProfile(forceRefresh: Bool = false) async throws -> UserProfile {
        guard let token = AppCore.shared.token else { 
            throw AppError.unauthorized 
        }
        
        let url = URLs.userProfile
        let headers: [String: String] = ["authorization": token]
        let cacheKey = CacheKey(url: url, method: .get, headers: headers)
        
        if !forceRefresh, let cachedData = try await cache.get(key: cacheKey) {
            return try JSONDecoder().decode(UserProfile.self, from: cachedData)
        }
        
        let data = try await fetchFromNetwork(url: url, headers: headers)
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)
        
        // User profiles change less frequently, cache for longer
        try await cache.set(data, for: cacheKey, ttl: 24 * 60 * 60) // 24 hours
        
        return profile
    }
    
    /// Fetch live data that changes frequently
    func getLiveScores(forceRefresh: Bool = false) async throws -> [Score] {
        let url = URLs.liveScores
        let cacheKey = CacheKey(url: url, method: .get)
        
        if !forceRefresh, let cachedData = try await cache.get(key: cacheKey) {
            return try JSONDecoder().decode([Score].self, from: cachedData)
        }
        
        let data = try await fetchFromNetwork(url: url, headers: [:])
        let scores = try JSONDecoder().decode([Score].self, from: data)
        
        // Live data: very short TTL
        try await cache.set(data, for: cacheKey, ttl: 30) // 30 seconds
        
        return scores
    }
    
    // MARK: - Helper Methods
    
    private func fetchFromNetwork(url: String, headers: [String: String]) async throws -> Data {
        // Replace with your actual Alamofire implementation
        // For example:
        // let response = try await AlamofireClient().task(
        //     url,
        //     method: .get,
        //     parameters: [:],
        //     encoding: .url,
        //     headers: headers
        // )
        // return response.data
        
        // Placeholder for example
        return Data()
    }
}

// MARK: - Example Models

struct Semester: Codable {
    let id: String
    let name: String
    let startDate: Date
    let endDate: Date
}

struct SemesterDTO: Codable {
    let id: String
    let name: String
    let startDate: String
    let endDate: String
    
    var model: Semester {
        // Convert DTO to model
        Semester(
            id: id,
            name: name,
            startDate: Date(),  // Parse from string
            endDate: Date()     // Parse from string
        )
    }
}

struct UserProfile: Codable {
    let id: String
    let name: String
    let email: String
}

struct Score: Codable {
    let id: String
    let value: Int
}

// MARK: - Example App Core

class AppCore {
    static let shared = AppCore()
    var token: String? = "example-token"
}

enum AppError: Error {
    case unauthorized
}

struct URLs {
    static let semesters = "https://api.example.com/semesters"
    static let userProfile = "https://api.example.com/profile"
    static let liveScores = "https://api.example.com/scores"
}

// MARK: - Usage Examples

func exampleUsage() async throws {
    let service = ModuleService()
    
    // Normal fetch (uses cache if available)
    let semesters = try await service.getSemesters()
    print("Loaded \(semesters.count) semesters")
    
    // Force refresh (bypasses cache)
    let freshSemesters = try await service.getSemesters(forceRefresh: true)
    print("Loaded \(freshSemesters.count) fresh semesters")
    
    // Check cache statistics
    let stats = await NetworkCache.shared.statistics()
    print("Cache hit rate: \(stats.hitRate)%")
    print("Total cached: \(stats.totalEntryCount) entries")
}
