//
//  NetworkService.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Monitors network reachability for purchase-related operations.
///
/// `NetworkService` wraps a reachability monitor and exposes:
/// - the current, classified connectivity state (`NetworkStatus`)
/// - main-thread delegate callbacks for status changes and connectivity events
///
/// Threading model:
/// - All internal state mutations happen exclusively on `networkQueue`.
/// - Public read access (`currentStatus`, `isMonitoring`, `canAttemptNetworkOperations`)
///   is synchronized via `networkQueue.sync`.
/// - Delegate callbacks are always dispatched to the main queue.
///
/// Usage pattern:
/// ```swift
/// final class MyClass: NetworkServiceDelegate {
///     private let networkService = NetworkService()
///
///     init() {
///         networkService.delegate = self
///         networkService.startMonitoring()
///     }
///
///     func networkService(_ service: NetworkService,
///                         didUpdateNetworkStatus status: NetworkService.NetworkStatus) {
///         // Update UI/logic based on reachability
///         // e.g. disable "Buy" button when offline.
///     }
///
///     func networkService(_ service: NetworkService,
///                         didEncounterError error: NetworkServiceError) {
///         // Optional: log or show a non-blocking message
///     }
/// }
/// ```
///
/// - Important:
///   This service reports reachability only. It does not automatically retry purchases
///   or queue operations. Higher-level components should decide how to react.
public final class NetworkService: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Represents the current connectivity state relevant to purchase operations.
    public enum NetworkStatus: Equatable, CustomStringConvertible, Sendable {
        
        /// Network reachable via Wi-Fi.
        case wifi
        /// Network reachable via cellular.
        case cellular
        /// No network connectivity available.
        case offline
        /// Connectivity could not be determined reliably.
        case unknown
        
        /// Human-readable status used for logging and diagnostics.
        public var description: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .offline: return "Offline"
            case .unknown: return "Unknown"
            }
        }
        
        public var localizedText: String {
            switch self {
            case .wifi: return "purchasekit.network_status.wifi".localized
            case .cellular: return "purchasekit.network_status.cellular".localized
            case .offline: return "purchasekit.network_status.offline".localized
            case .unknown: return "purchasekit.network_status.unknown".localized
            }
        }
        
        /// Returns `true` if network-dependent operations should be attempted.
        public var allowsNetworkOperations: Bool {
            switch self {
            case .wifi, .cellular: return true
            case .offline, .unknown: return false
            }
        }
    }
    
    // MARK: - Public API
    
    /// Receives network events. All delegate calls are delivered on the main queue.
    weak var delegate: NetworkServiceDelegate?
    
    /// The latest known network status (thread-safe).
    ///
    /// - Note: Reads are synchronized through `networkQueue`.
    var currentStatus: NetworkStatus {
        networkQueue.sync { _currentStatus }
    }
    
    /// Convenience flag indicating whether network operations should be attempted (thread-safe).
    var canAttemptNetworkOperations: Bool {
        networkQueue.sync { _currentStatus.allowsNetworkOperations }
    }
    
    /// Indicates whether monitoring is currently active (thread-safe).
    var isMonitoring: Bool {
        networkQueue.sync { _isMonitoring }
    }
    
    // MARK: - Private State (queue-isolated)
    
    /// Reachability instance used to observe connectivity changes.
    private var reachability: Reachability?
    
    /// Queue-isolated backing store for `currentStatus`.
    private var _currentStatus: NetworkStatus = .unknown
    
    /// Queue-isolated backing store for `isMonitoring`.
    private var _isMonitoring: Bool = false
    
    /// Dedicated queue used to isolate all internal state mutations.
    private let networkQueue = DispatchQueue(label: "com.purchaseKit.iap.network", qos: .background)
    
    // MARK: - Initialization
    
    /// Creates a new network service. Call `startMonitoring()` to begin updates.
    init() {
        IAPLogger.log("NetworkService initialized")
    }
    
    /// Stops monitoring and releases resources.
    deinit {
        networkQueue.sync { cleanupLocked() }
        NotificationCenter.default.removeObserver(self)
        IAPLogger.log("NetworkService deinitialized")
    }
    
    // MARK: - Monitoring
    
    /// Starts network monitoring (idempotent).
    ///
    /// If monitoring is already active, this method does nothing.
    func startMonitoring() {
        networkQueue.async { [weak self] in
            guard let self else { return }
            guard self._isMonitoring == false else {
                IAPLogger.log("Network monitoring already active", level: .info)
                return
            }
            self.setupLocked()
        }
    }
    
    /// Stops network monitoring (idempotent).
    ///
    /// If monitoring is not active, this method does nothing.
    func stopMonitoring() {
        networkQueue.async { [weak self] in
            guard let self else { return }
            guard self._isMonitoring == true else { return }
            self.cleanupLocked()
        }
    }
    
    /// Forces a status re-evaluation (only if monitoring is active).
    ///
    /// This can be used for troubleshooting or to force an initial delegate update.
    func refreshNetworkStatus() {
        networkQueue.async { [weak self] in
            guard let self else { return }
            guard self._isMonitoring == true else {
                IAPLogger.log("Cannot refresh network status - monitoring not active", level: .warning)
                return
            }
            self.updateNetworkStatusLocked(alwaysNotify: true)
        }
    }
    
    // MARK: - Setup / Cleanup (queue-only)
    
    /// Initializes reachability, registers notifications and starts the notifier.
    private func setupLocked() {
        do {
            reachability = try Reachability()
            _isMonitoring = true
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleReachabilityChange(_:)),
                name: .reachabilityChanged,
                object: nil
            )
            
            try reachability?.startNotifier()
            
            updateNetworkStatusLocked(alwaysNotify: true)
            IAPLogger.log("Network monitoring started successfully")
            
        } catch {
            IAPLogger.log("Failed to start network monitoring: \(error.localizedDescription)", level: .error)
            cleanupLocked()
            _currentStatus = .unknown
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.networkService(self, didEncounterError: .monitoringSetupFailed(underlying: error))
            }
        }
    }
    
    /// Stops the notifier and releases reachability resources.
    private func cleanupLocked() {
        reachability?.stopNotifier()
        reachability = nil
        _isMonitoring = false
        IAPLogger.log("Network monitoring stopped")
    }
    
    // MARK: - Notifications
    
    /// Handles reachability notifications and forwards processing to `networkQueue`.
    @objc private func handleReachabilityChange(_ notification: Notification) {
        networkQueue.async { [weak self] in
            guard let self else { return }
            
            guard self._isMonitoring, self.reachability != nil else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.networkService(self, didEncounterError: .monitoringInterrupted)
                }
                return
            }
            
            self.updateNetworkStatusLocked(alwaysNotify: false)
        }
    }
    
    // MARK: - Status Update (queue-only)
    
    /// Derives `NetworkStatus` from reachability and notifies the delegate if needed.
    private func updateNetworkStatusLocked(alwaysNotify: Bool) {
        guard let reachability else {
            IAPLogger.log("Cannot update network status - no reachability instance", level: .warning)
            return
        }
        
        let previous = _currentStatus
        
        switch reachability.connection {
        case .wifi: _currentStatus = .wifi
        case .cellular: _currentStatus = .cellular
        case .unavailable, .none: _currentStatus = .offline
        @unknown default: _currentStatus = .unknown
        }
        
        let changed = (previous != _currentStatus)
        
        if changed || alwaysNotify {
            IAPLogger.log("Network status: \(previous.description) → \(_currentStatus.description)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                self.delegate?.networkService(self, didUpdateNetworkStatus: self._currentStatus)
                
                if previous.allowsNetworkOperations && !self._currentStatus.allowsNetworkOperations {
                    self.delegate?.networkService(self, didLoseNetworkConnectivity: self._currentStatus)
                } else if !previous.allowsNetworkOperations && self._currentStatus.allowsNetworkOperations {
                    self.delegate?.networkService(self, didRestoreNetworkConnectivity: self._currentStatus)
                }
            }
        } else {
            IAPLogger.log("Network status confirmed: \(_currentStatus.description)", level: .info)
        }
    }
}
