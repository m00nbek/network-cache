import Foundation
import Network

/// Handles offline mode and network reachability
actor OfflineModeHandler {
    private let diskCache: DiskCache
    private let maxStaleAge: TimeInterval
    private var monitor: NWPathMonitor?
    private var isCurrentlyOffline = false
    
    init(diskCache: DiskCache, maxStaleAge: TimeInterval) {
        self.diskCache = diskCache
        self.maxStaleAge = maxStaleAge
        
        // Start monitoring network status (asynchronously)
        Task { await self.startMonitoring() }
    }
    
    deinit {
        // Note: Can't call async methods in deinit, monitor will be cancelled when actor is deallocated
    }
    
    /// Start monitoring network connectivity
    private func startMonitoring() {
        let monitor = NWPathMonitor()
        self.monitor = monitor
        
        monitor.pathUpdateHandler = { [weak self] path in
            Task {
                await self?.updateNetworkStatus(path.status == .satisfied)
            }
        }
        
        let queue = DispatchQueue(label: "com.networkcache.monitor")
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring network connectivity
    private func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }
    
    /// Update the current network status
    private func updateNetworkStatus(_ isOnline: Bool) {
        isCurrentlyOffline = !isOnline
        
        #if DEBUG
        print("[OfflineModeHandler] Network status: \(isOnline ? "Online" : "Offline")")
        #endif
    }
    
    /// Check if currently offline
    func isOffline() -> Bool {
        isCurrentlyOffline
    }
    
    /// Get stale cache data for a key if offline
    func getStaleData(for key: CacheKey) async -> Data? {
        // Only serve stale data if offline
        guard isCurrentlyOffline else {
            return nil
        }
        
        // Get stale entries from disk cache
        let staleEntries = await diskCache.getStaleEntries(maxStaleAge: maxStaleAge)
        
        // Find entry matching the key
        if let entry = staleEntries[key.hashedValue] {
            #if DEBUG
            print("[OfflineModeHandler] Serving stale cache for \(key.debugDescription)")
            #endif
            return entry.data
        }
        
        return nil
    }
}
