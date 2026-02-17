//
//  PurchaseConstants.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Centralized constants used by PurchaseKit.
///
/// Use reverse-DNS names to avoid collisions with other libraries or the host app.
/// Include a version suffix for persisted keys to allow future migrations.
enum PurchaseConstants {
    
    enum UserDefaultsKeys {
        
        /// Cached entitlement snapshot keyed by StoreKit product id.
        static let entitlements = "io.github.mrpalme.purchasekit.entitlements.v1"
        
        /// (Optional) Legacy key for older builds. Keep only if you need migration.
        static let legacyPurchaseStates = "io.github.mrpalme.purchasekit.purchaseStates.v1"
    }
}

extension Notification.Name {
    /// Posted whenever the effective entitlement set changes.
    static let entitlementDidChange = Notification.Name("io.github.mrpalme.purchasekit.entitlementDidChange")
}
