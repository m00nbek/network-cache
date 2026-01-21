import Foundation

/// Errors that can occur during cache operations
public enum NetworkCacheError: LocalizedError {
    /// Cache entry not found
    case entryNotFound
    
    /// Failed to encode cache entry
    case encodingFailed(Error)
    
    /// Failed to decode cache entry
    case decodingFailed(Error)
    
    /// Failed to write to disk
    case diskWriteFailed(Error)
    
    /// Failed to read from disk
    case diskReadFailed(Error)
    
    /// Cache directory creation failed
    case directoryCreationFailed(Error)
    
    /// Cache is full and eviction failed
    case cacheFull
    
    /// Invalid cache key
    case invalidKey
    
    /// Operation cancelled
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .entryNotFound:
            return "Cache entry not found"
        case .encodingFailed(let error):
            return "Failed to encode cache entry: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode cache entry: \(error.localizedDescription)"
        case .diskWriteFailed(let error):
            return "Failed to write to disk: \(error.localizedDescription)"
        case .diskReadFailed(let error):
            return "Failed to read from disk: \(error.localizedDescription)"
        case .directoryCreationFailed(let error):
            return "Failed to create cache directory: \(error.localizedDescription)"
        case .cacheFull:
            return "Cache is full and eviction failed"
        case .invalidKey:
            return "Invalid cache key"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}
