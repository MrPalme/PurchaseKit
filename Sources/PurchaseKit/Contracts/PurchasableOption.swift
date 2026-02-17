//
//  PurchasableOption.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Represents a purchasable option that maps 1:1 to a StoreKit product.
///
/// Typical examples:
/// - "Pro Monthly" (auto-renewable subscription)
/// - "Pro Yearly" (auto-renewable subscription)
/// - "Lifetime" (non-consumable)
public protocol PurchasableOption: Hashable, Sendable {
    
    /// A stable identifier for app-side routing/analytics (not necessarily the StoreKit id).
    var id: String { get }
    
    /// The StoreKit product identifier (must match App Store Connect).
    var productId: String { get }
    
    /// The product category used to drive entitlement logic.
    var purchaseType: PurchaseType { get }
    
    /// Title shown in UI (localized by the host app).
    var title: String { get }
    
    /// Optional subtitle shown in UI (localized by the host app).
    var subtitle: String? { get }
    
    /// Sorting order for UI presentation (lower values appear first).
    var sortOrder: Int { get }
    
    /// Optional offering/group identifier this option belongs to.
    /// Use this to group multiple options (e.g. monthly/yearly) under one plan.
    var offeringId: String? { get }
    
    /// Optional badge (e.g. "Best Value", "Most Popular", "Save 20%").
    var badge: TierBadge? { get }
}
