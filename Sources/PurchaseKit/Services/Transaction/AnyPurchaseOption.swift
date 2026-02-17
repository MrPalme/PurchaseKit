//
//  AnyPurchaseOption.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Type-erased purchase option used for delegate callbacks and listener mapping.
///
/// StoreKit exposes purchases and transactions primarily via `productID` (`Product.id` / `Transaction.productID`).
/// To keep PurchaseKit host-app agnostic, `TransactionService` maps those product identifiers back to an app-defined
/// `PurchaseOption` using `PurchaseOption.productId`. For delegate callbacks, the option is forwarded as
/// `AnyPurchaseOption` to avoid leaking the host app's concrete option types (enums/structs).
///
/// Usage pattern:
/// ```swift
/// func transactionService(_ service: TransactionService,
///                         didUpdateEntitlement entitlement: EntitlementState,
///                         for option: AnyPurchaseOption) {
///     // Map back to your concrete option type if needed:
///     // let concrete = optionsByProductId[option.productId]
/// }
/// ```
///
/// - Important:
///   `AnyPurchaseOption` is a snapshot of the option’s metadata at the time it was created.
///   If the host app changes titles/badges dynamically, create new options and call `startListening(options:)` again.
public struct AnyPurchaseOption: Hashable, Sendable {
    
    /// Stable app-side identifier for routing/analytics.
    ///
    /// This is **not** required to equal `productId`. Many apps simply set `id == productId`,
    /// but you can also use a custom identifier (e.g. "pro_yearly").
    public let id: String
    
    /// The StoreKit product identifier (must match App Store Connect).
    ///
    /// This value is used as the primary lookup key when mapping StoreKit transactions
    /// back to a purchase option.
    public let productId: String
    
    /// The product category used to drive entitlement logic.
    ///
    /// Typical values are `.autoRenewableSubscription` or `.nonConsumable`.
    /// PurchaseKit can use this to apply category-specific rules (e.g. expiry handling).
    public let purchaseType: PurchaseType
    
    /// Localized title shown in UI (provided by the host app).
    public let title: String
    
    /// Optional localized subtitle shown in UI (provided by the host app).
    public let subtitle: String?
    
    /// Sorting order for UI presentation (lower values appear first).
    public let sortOrder: Int
    
    /// Optional offering/group identifier this option belongs to.
    ///
    /// Use this to group multiple options (e.g. monthly/yearly) under one plan.
    /// Example: "pro" for both "pro_monthly" and "pro_yearly".
    public let offeringId: String?
    
    /// Optional badge shown in UI (e.g. "Best Value", "Most Popular", "Save 20%").
    public let badge: TierBadge?
    
    /// Creates a type-erased representation of a concrete `PurchaseOption`.
    ///
    /// - Parameter option: The host app's concrete option instance.
    public init<Option: PurchaseOption>(_ option: Option) {
        self.id = option.id
        self.productId = option.productId
        self.purchaseType = option.purchaseType
        self.title = option.title
        self.subtitle = option.subtitle
        self.sortOrder = option.sortOrder
        self.offeringId = option.offeringId
        self.badge = option.badge
    }
}
