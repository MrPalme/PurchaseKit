//
//  NetworkServiceDelegate.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Receives network status updates and connectivity events from `NetworkService`.
///
/// All delegate methods are called on the **main thread**, so it is safe to update UI
/// or publish view state directly from these callbacks.
///
/// Usage pattern:
/// ```swift
/// final class MyClass: NetworkServiceDelegate {
///     func networkService(_ service: NetworkService,
///                         didUpdateNetworkStatus status: NetworkService.NetworkStatus) {
///         // e.g. enable/disable purchase buttons
///     }
///
///     func networkService(_ service: NetworkService,
///                         didRestoreNetworkConnectivity status: NetworkService.NetworkStatus) {
///         // e.g. retry loading products
///     }
///
///     func networkService(_ service: NetworkService,
///                         didLoseNetworkConnectivity status: NetworkService.NetworkStatus) {
///         // e.g. switch UI to offline state
///     }
///
///     func networkService(_ service: NetworkService,
///                         didEncounterError error: NetworkServiceError) {
///         // e.g. log error, show a non-blocking message
///     }
/// }
/// ```
public protocol NetworkServiceDelegate: AnyObject {
    
    /// Called whenever the network status changes.
    ///
    /// Use this callback to react to any transition (e.g. Wi-Fi → Cellular, Online → Offline).
    ///
    /// - Parameters:
    ///   - service: The reporting network service.
    ///   - status: The newly derived network status.
    func networkService(_ service: NetworkService, didUpdateNetworkStatus status: NetworkService.NetworkStatus)
    
    /// Called when connectivity transitions from a non-operational state to an operational state.
    ///
    /// This is a convenience callback for handling recovery actions (e.g. reload products).
    ///
    /// - Parameters:
    ///   - service: The reporting network service.
    ///   - status: The restored connection type (typically `.wifi` or `.cellular`).
    func networkService(_ service: NetworkService, didRestoreNetworkConnectivity status: NetworkService.NetworkStatus)
    
    /// Called when connectivity transitions from an operational state to a non-operational state.
    ///
    /// - Parameters:
    ///   - service: The reporting network service.
    ///   - status: The current state (typically `.offline` or `.unknown`).
    func networkService(_ service: NetworkService, didLoseNetworkConnectivity status: NetworkService.NetworkStatus)
    
    /// Called when the network service encounters a monitoring-related error.
    ///
    /// - Parameters:
    ///   - service: The reporting network service.
    ///   - error: The encountered error.
    func networkService(_ service: NetworkService, didEncounterError error: NetworkServiceError)
}
