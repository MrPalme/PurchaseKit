//
//  PromoCodeError.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Defines errors that can occur while presenting or handling promotional code redemption.
///
/// Promo code redemption has specific failure scenarios that are distinct from standard
/// purchase flows (e.g. feature availability on the current OS version).
///
/// Use these errors to provide user-facing guidance when the redemption sheet cannot be
/// presented or the user flow is interrupted.
///
/// - Note:
///   This type models presentation/availability errors. The actual redemption result is
///   handled by the App Store and will be reflected in entitlements/transactions.
public enum PromoCodeError: Error, Equatable, Sendable {
    
    /// Promo code redemption is not available on the current device or OS version.
    ///
    /// For example, the API may be unavailable due to the minimum iOS requirement.
    case notAvailable
    
    /// The user dismissed the redemption flow without completing it.
    case userCancelled
    
    /// A system-level error occurred while attempting to present the redemption UI.
    case systemError
}

extension PromoCodeError: LocalizedError {
    
    /// A user-friendly message suitable for alerts and UI.
    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "purchasekit.promocode.not_available".localized
        case .userCancelled:
            return "purchasekit.promocode.user_cancelled".localized
        case .systemError:
            return "purchasekit.promocode.system_error".localized
        }
    }
}
