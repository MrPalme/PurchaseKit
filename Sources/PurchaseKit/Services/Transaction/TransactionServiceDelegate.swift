//
//  TransactionServiceDelegate.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Receives entitlement updates and purchase/restore outcomes from `TransactionService`.
///
/// All callbacks are delivered on the main thread.
///
/// The delegate uses `AnyPurchaseOption` so the service can report updates even when
/// the host app uses custom `PurchaseOption` types (enums/structs).
public protocol TransactionServiceDelegate: AnyObject {
    
    /// Called when a verified transaction results in a new entitlement state for an option.
    ///
    /// This callback may be triggered by:
    /// - a user-initiated purchase
    /// - subscription renewals / expirations
    /// - refunds / revocations
    /// - purchases made on other devices
    ///
    /// - Parameters:
    ///   - service: The reporting transaction service.
    ///   - entitlement: The derived entitlement state.
    ///   - option: The affected option (type-erased).
    func transactionService(_ service: TransactionService,
                            didUpdateEntitlement entitlement: EntitlementState,
                            for option: AnyPurchaseOption)
    
    /// Called when a restore operation fails.
    func transactionService(_ service: TransactionService, didFailRestore error: PurchaseError)
    
    /// Called when restore completes successfully with an entitlement snapshot.
    func transactionService(_ service: TransactionService,
                            didFinishRestoreWith entitlements: [AnyPurchaseOption: EntitlementState])
    
    /// Called when a purchase attempt fails (e.g. cancelled, verification failed).
    func transactionService(_ service: TransactionService,
                            didFailPurchaseFor option: AnyPurchaseOption,
                            error: PurchaseError)
    
    /// Called when StoreKit reports a purchase as pending.
    ///
    /// Pending purchases require external approval (e.g. Family Sharing / Ask to Buy).
    func transactionService(_ service: TransactionService, didSetPendingFor option: AnyPurchaseOption)
}
