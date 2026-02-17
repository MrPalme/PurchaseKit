//
//  NetworkServiceError.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Defines errors related to network monitoring and connectivity services.
///
/// This error type focuses on failures around setting up and running a network
/// monitoring mechanism (e.g. `NWPathMonitor`) that the purchase flow may rely on.
public enum NetworkServiceError: Error, Sendable {
    
    /// Network monitoring could not be initialized.
    ///
    /// The associated error contains the underlying system failure details.
    case monitoringSetupFailed(underlying: Error)
    
    /// Network monitoring was stopped or interrupted unexpectedly.
    case monitoringInterrupted
}

extension NetworkServiceError: LocalizedError {
    
    /// A user-facing description suitable for UI alerts.
    public var errorDescription: String? {
        switch self {
        case .monitoringSetupFailed:
            return "purchasekit.network.monitoring_setup_failed".localized
        case .monitoringInterrupted:
            return "purchasekit.network.monitoring_interrupted".localized
        }
    }
}

extension NetworkServiceError: CustomDebugStringConvertible {
    
    /// A detailed, technical description intended for logging and diagnostics.
    public var debugDescription: String {
        switch self {
        case .monitoringSetupFailed(let underlying):
            return "Network monitoring setup failed: \(underlying.localizedDescription)"
        case .monitoringInterrupted:
            return "Network monitoring was interrupted unexpectedly."
        }
    }
}
