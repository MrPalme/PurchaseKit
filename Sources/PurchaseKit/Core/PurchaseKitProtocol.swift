//
//  PurchaseKitManagerProtocol.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation
import StoreKit
import UIKit

/// Public interface for purchase management within PurchaseKit.
///
/// This protocol abstracts the concrete manager implementation to enable:
/// - dependency injection
/// - unit testing with mocks
/// - swapping implementations without changing host app code
///
/// The manager supports both:
/// - delegate callbacks (UIKit-friendly)
/// - async/await APIs (modern Swift)
///
/// The host app defines purchasable items via `PurchaseOption` and groups subscription
/// alternatives (e.g. monthly/yearly) using `PurchaseOption.offeringId`.
///
/// Usage pattern:
/// ```swift
/// final class AppPurchaseCoordinator {
///     private let manager: PurchaseKitManagerProtocol
///     private let options: [AppPurchaseOption]
///
///     init(manager: PurchaseKitManagerProtocol, options: [AppPurchaseOption]) {
///         self.manager = manager
///         self.options = options
///
///         self.manager.configure(options: options)
///         self.manager.delegate = self
///     }
/// }
/// ```
@MainActor
public protocol PurchaseKitManagerProtocol: AnyObject {
    
    // MARK: - Delegate
    
    /// Receives product load events, entitlement changes, restore outcomes, and errors.
    ///
    /// - Important: Delegate callbacks must be delivered on the main thread.
    var delegate: PurchaseKitDelegate? { get set }
    
    // MARK: - State
    
    /// Latest entitlement snapshot for all configured purchase options.
    ///
    /// This dictionary is the primary source for enabling/disabling features.
    /// It is derived from StoreKit transactions / current entitlements.
    var entitlements: [AnyPurchaseOption: EntitlementState] { get }
    
    /// Latest transient purchase flow state (UI helper).
    ///
    /// Intended for UI concerns only (spinners, button disabling, inline errors).
    var flowState: PurchaseFlowState { get }
    
    /// Products loaded from the App Store for configured `PurchaseOption.productId`s.
    var availableProducts: [Product] { get }
    
    // MARK: - Configuration
    
    /// Configures the manager with the host app's purchasable options.
    ///
    /// Call this once early (e.g., app start / paywall coordinator init).
    /// The manager uses the provided options to:
    /// - map StoreKit `productID` back to options
    /// - build entitlement snapshots
    /// - enforce subscription exclusivity within an offering (optional)
    ///
    /// - Parameter options: The host app's purchasable options.
    func configure<Option: PurchasableOption>(options: [Option])
    
    // MARK: - Product Loading
    
    /// Loads StoreKit products for the configured options.
    ///
    /// This fetches localized pricing and product metadata from the App Store.
    /// Must be called before initiating purchases (you need a resolved `Product`).
    ///
    /// - Note: Results are also delivered via delegate callbacks.
    func loadProducts() async
    
    // MARK: - Purchase
    
    /// Initiates a purchase flow for the given option.
    ///
    /// The manager resolves the matching StoreKit `Product` and calls `purchase()`.
    /// Purchase and entitlement updates are emitted via the delegate.
    ///
    /// - Parameter option: The option to purchase.
    /// - Throws: `PurchaseError` when the purchase fails or cannot be started.
    func purchase(_ option: AnyPurchaseOption) async throws
    
    /// Initiates a purchase flow for the given typed `PurchaseOption`.
    ///
    /// This overload is a convenience for host apps that still work with their own
    /// strongly-typed option models (e.g. enums/structs). Internally the option is
    /// type-erased into `AnyPurchaseOption` and routed through the main purchase API.
    ///
    /// The manager resolves the matching StoreKit `Product` and triggers `Product.purchase()`.
    /// Entitlement updates and UI flow state changes are reported via the delegate.
    ///
    /// Usage pattern:
    /// ```swift
    /// enum AppOption: PurchaseOption {
    ///     case proMonthly, proYearly
    ///     // ... conformance ...
    /// }
    ///
    /// try await manager.purchase(AppOption.proMonthly)
    /// ```
    ///
    /// - Parameter option: The typed purchase option defined by the host app.
    /// - Throws: `PurchaseError` when the purchase fails or cannot be started.
    func purchase<Option: PurchasableOption>(_ option: Option) async throws
    
    // MARK: - Restore / Refresh
    
    /// Restores purchases by syncing with the App Store and rebuilding entitlements.
    ///
    /// Required by App Store guidelines for non-consumables and subscriptions.
    /// Results are emitted via the delegate as a full entitlement snapshot.
    func restorePurchases<Option: PurchasableOption>(options: [Option]) async
    
    /// Refreshes entitlements from the App Store without showing UI.
    ///
    /// Call this on app foreground to detect renewals, cancellations, refunds, etc.
    func refreshPurchases<Option: PurchasableOption>(options: [Option]) async
    
    // MARK: - Lookup
    
    /// Returns the current entitlement state for the given option.
    ///
    /// - Parameter option: The option to query.
    /// - Returns: Current entitlement state (defaults to `.inactive` when unknown).
    func entitlementState(for option: AnyPurchaseOption) -> EntitlementState
    
    /// Convenience check for feature gating.
    ///
    /// - Parameter option: The option to query.
    /// - Returns: `true` if the entitlement is currently active.
    func isEntitled(_ option: AnyPurchaseOption) -> Bool
    
    /// Returns a loaded StoreKit product matching an option (if available).
    ///
    /// - Parameter option: The option to resolve.
    /// - Returns: A matching `Product` or `nil` if products were not loaded yet.
    func product(for option: AnyPurchaseOption) -> Product?
    
    // MARK: - Promo Codes
    
    /// Presents Apple's native promo code redemption sheet.
    ///
    /// This uses the system UI for code redemption. StoreKit will emit resulting
    /// entitlement changes asynchronously via transaction updates.
    ///
    /// - Parameter presentingViewController: The view controller used to present the sheet.
    /// - Throws: `PromoCodeError` if the sheet cannot be presented.
    ///
    /// - Important: Must be called from a UIKit presentation context.
    func presentPromoCodeRedemption(from presentingViewController: UIViewController) async throws
}
