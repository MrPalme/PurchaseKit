//
//  PurchaseKitDelegate.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation
import StoreKit

/// Delegate protocol for receiving purchase-related events and entitlement changes from PurchaseKit.
///
/// This delegate is intended for UIKit-compatible, callback-based integration.
/// All methods are invoked on the **main thread**.
///
/// The delegate reports:
/// - resolved StoreKit products (prices, localized titles)
/// - entitlement changes derived from StoreKit transactions/current entitlements
/// - restore outcomes
/// - errors during load/purchase/restore flows
///
/// Usage pattern:
/// ```swift
/// final class PaywallViewController: UIViewController, PurchaseKitDelegate {
///     private let manager: PurchaseKitManagerProtocol
///
///     init(manager: PurchaseKitManagerProtocol) {
///         self.manager = manager
///         super.init(nibName: nil, bundle: nil)
///         self.manager.delegate = self
///     }
///
///     func purchaseKitManager(_ manager: PurchaseKitManagerProtocol,
///                             didUpdateEntitlement entitlement: EntitlementState,
///                             for option: AnyPurchaseOption) {
///         // Update UI / unlock features
///     }
/// }
/// ```
///
/// - Important: All delegate methods are called on the main thread.
/// - Note: This delegate can coexist with Combine/async APIs if you expose both.
public protocol PurchaseKitDelegate: AnyObject {
    
    /// Called when StoreKit products were successfully loaded.
    ///
    /// Use this to update UI with localized pricing and product details.
    ///
    /// - Parameters:
    ///   - manager: The purchase manager instance.
    ///   - products: The loaded StoreKit products.
    func purchaseKitManager(_ manager: PurchaseKitManagerProtocol,
                            didLoadProducts products: [Product])
    
    /// Called when loading StoreKit products failed.
    ///
    /// Typical causes:
    /// - no network connectivity
    /// - invalid product identifiers
    /// - App Store service issues
    ///
    /// - Parameters:
    ///   - manager: The purchase manager instance.
    ///   - error: The error describing the failure.
    func purchaseKitManager(_ manager: PurchaseKitManagerProtocol,
                            didFailToLoadProductsWith error: PurchaseError)
    
    /// Called when an option's entitlement changed.
    ///
    /// This is the primary callback to enable/disable features.
    /// It may be triggered by:
    /// - a successful user-initiated purchase
    /// - subscription renewals/expirations
    /// - refunds/revocations
    /// - restore/sync operations
    /// - background StoreKit transaction updates
    ///
    /// - Parameters:
    ///   - manager: The purchase manager instance.
    ///   - entitlement: The derived entitlement state.
    ///   - option: The affected option (type-erased).
    func purchaseKitManager(_ manager: PurchaseKitManagerProtocol,
                            didUpdateEntitlement entitlement: EntitlementState,
                            for option: AnyPurchaseOption)
    
    /// Called when the purchase UI flow state changes (optional UI helper).
    ///
    /// Use this to:
    /// - show/hide spinners
    /// - disable purchase buttons
    /// - show inline errors
    ///
    /// - Parameters:
    ///   - manager: The purchase manager instance.
    ///   - state: The transient flow state.
    func purchaseKitManager(_ manager: PurchaseKitManagerProtocol,
                            didUpdateFlowState state: PurchaseFlowState)
    
    /// Called when a restore/sync operation completed with an entitlement snapshot.
    ///
    /// - Parameters:
    ///   - manager: The purchase manager instance.
    ///   - entitlements: Snapshot mapping each known option to its entitlement state.
    func purchaseKitManager(_ manager: PurchaseKitManagerProtocol,
                            didCompleteRestoreWith entitlements: [AnyPurchaseOption: EntitlementState])
    
    /// Called when a restore operation failed.
    ///
    /// - Parameters:
    ///   - manager: The purchase manager instance.
    ///   - error: The error describing the failure.
    func purchaseKitManager(_ manager: PurchaseKitManagerProtocol,
                            didFailRestoreWith error: PurchaseError)
    
    /// Called when a purchase attempt for an option failed.
    ///
    /// - Parameters:
    ///   - manager: The purchase manager instance.
    ///   - option: The option that failed.
    ///   - error: The error describing the failure.
    func purchaseKitManager(_ manager: PurchaseKitManagerProtocol,
                            didFailPurchaseFor option: AnyPurchaseOption,
                            error: PurchaseError)
}
