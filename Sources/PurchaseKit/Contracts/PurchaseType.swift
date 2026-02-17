//
//  PurchaseType.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

/// Represents the high-level category of an in-app purchase.
///
/// Use `PurchaseType` to classify StoreKit products and to drive purchase/entitlement logic,
/// for example:
/// - whether an item can be purchased multiple times (`consumable`)
/// - whether a purchase should unlock a permanent entitlement (`nonConsumable`)
/// - whether access should be time-bound (`autoRenewableSubscription`, `nonRenewingSubscription`)
///
/// This enum is intentionally aligned with StoreKit product families, but kept app-agnostic
/// so it can be used in shared purchase libraries.
///
/// - Note:
///   StoreKit 2 exposes product type information on `StoreKit.Product` as well, but
///   many apps keep their own classification to map product IDs to business logic.
public enum PurchaseType: Sendable {
    
    /// A one-time purchase that permanently unlocks content or functionality.
    ///
    /// Typical examples: “Remove Ads”, “Pro Upgrade”, “Unlock Feature X”.
    case nonConsumable
    
    /// A purchase that can be bought repeatedly and is consumed when used.
    ///
    /// Typical examples: in-game currency, single-use tokens, consumable credits.
    case consumable
    
    /// A subscription that renews automatically until the user cancels.
    ///
    /// Access remains active while the subscription is in good standing.
    case autoRenewableSubscription
    
    /// A subscription that lasts for a fixed duration and does not auto-renew.
    ///
    /// Access expires after the purchased period ends; the user must purchase again to extend.
    case nonRenewingSubscription
}
