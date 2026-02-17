//
//  PurchaseError.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation
import StoreKit

/// Comprehensive error types for in-app purchase operations.
///
/// Maps StoreKit errors and system errors to user-friendly, actionable error messages.
/// Each error type includes localized descriptions suitable for displaying to users.
///
/// Usage:
/// ```swift
/// do {
///     try await purchaseManager.purchase(.premium)
/// } catch let error as PurchaseError {
///     showAlert(error.localizedDescription)
/// }
/// ```
///
/// - Note: Error handling should be granular enough to provide specific user guidance
public enum PurchaseError: Error, Equatable {
    
    /// User cancelled the purchase in App Store dialog
    case userCancelled
    /// Purchase requires approval (parental controls, etc.)
    case pending
    /// Network connection required for purchase
    case networkError
    /// System-level error occurred
    case systemError
    /// Requested product is not available for purchase
    case productUnavailable
    /// Purchases are disabled on this device/account
    case purchaseNotAllowed
    /// App Store service problem
    case storeProblem
    /// Unknown error with custom description
    case unknown(description: String)
    
    /// User-friendly error message appropriate for display in alerts or UI.
    ///
    /// These messages should be actionable when possible, guiding users toward
    /// resolution steps.
    ///
    /// - Returns: Localized error description
    var localizedDescription: String {
        switch self {
        case .userCancelled:
            return "purchasekit.purchase_error.user_cancelled".localized
        case .pending:
            return "purchasekit.purchase_error.pending".localized
        case .networkError:
            return "purchasekit.purchase_error.network".localized
        case .systemError:
            return "purchasekit.purchase_error.system".localized
        case .productUnavailable:
            return "purchasekit.purchase_error.product_unavailable".localized
        case .purchaseNotAllowed:
            return "purchasekit.purchase_error.not_allowed".localized
        case .storeProblem:
            return "purchasekit.purchase_error.store_problem".localized
        case .unknown(let description):
            return description
        }
    }
}
