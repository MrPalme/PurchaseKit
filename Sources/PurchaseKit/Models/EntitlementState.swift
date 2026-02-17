//
//  EntitlementState.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Describes the user's current access (entitlement) for a product.
///
/// This state is derived from StoreKit transactions/current entitlements and
/// should be the primary source for enabling or disabling features.
public enum EntitlementState: Equatable, Sendable, Hashable {
    
    /// No active entitlement exists for the product.
    case inactive
    
    /// Permanent unlock (non-consumable) is active.
    case nonConsumable(transactionID: UInt64)
    
    /// Subscription is active until the given expiration date.
    case subscriptionActive(expirationDate: Date, transactionID: UInt64)
    
    /// Subscription existed but is no longer active.
    case subscriptionExpired(expirationDate: Date)
    
    /// Entitlement is revoked/refunded by the App Store.
    case revoked(revocationDate: Date)
    
    /// Returns `true` if the user should currently receive the product benefits.
    public var isActive: Bool {
        switch self {
        case .nonConsumable, .subscriptionActive:
            return true
        default:
            return false
        }
    }
}
