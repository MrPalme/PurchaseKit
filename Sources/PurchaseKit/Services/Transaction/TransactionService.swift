//
//  TransactionService.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation
import StoreKit

/// Processes StoreKit 2 transactions and derives entitlement state for `PurchaseOption`s.
///
/// `TransactionService` encapsulates StoreKit 2 transaction handling:
/// - initiates purchases via `Product.purchase()`
/// - listens for background transaction updates via `Transaction.updates`
/// - synchronizes current entitlements via `Transaction.currentEntitlements`
/// - finishes verified transactions to prevent duplicate deliveries
///
/// The service is host-app agnostic. Mapping happens through `PurchaseOption.productId`.
/// Delegate callbacks are always delivered on the main thread.
///
/// Usage pattern:
/// ```swift
/// final class InAppPurchaseManager: TransactionServiceDelegate {
///     private let txService = TransactionService()
///     private let options: [AppPurchaseOption]
///
///     init(options: [AppPurchaseOption]) {
///         self.options = options
///         txService.delegate = self
///         txService.startListening(options: options)
///     }
/// }
/// ```
///
/// - Important:
///   StoreKit is the source of truth. Persisted entitlements (if any) are cache only.
public final class TransactionService: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Receives entitlement updates and purchase/restore outcomes (main-thread callbacks).
    public weak var delegate: TransactionServiceDelegate?
    
    /// Background task listening to StoreKit transaction updates.
    private var transactionListener: Task<Void, Never>?
    
    /// Lookup used to map StoreKit `productID` → `PurchaseOption`.
    /// Must only be accessed from `listenerQueue`.
    private var optionByProductId: [String: AnyPurchaseOption] = [:]
    
    /// Serial queue to isolate listener state without forcing `@MainActor`.
    private let listenerQueue = DispatchQueue(label: "com.purchasekit.transaction.listener", qos: .utility)
    
    // MARK: - Initialization
    
    public init() { }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Public API
    
    /// Starts the background listener for transaction updates.
    ///
    /// The listener is required to handle transactions that happen outside the app flow:
    /// - subscription renewals
    /// - refunds / revocations
    /// - purchases on other devices
    ///
    /// - Parameter options: The set of options that should be recognized and mapped.
    public func startListening<Option: PurchasableOption>(options: [Option]) {
        // Build mapping outside the queue to avoid capturing `options` in a potentially @Sendable closure.
        let map = Dictionary(uniqueKeysWithValues: options.map { ($0.productId, AnyPurchaseOption($0)) })
        
        listenerQueue.async { [weak self] in
            self?.optionByProductId = map
        }
        
        // Idempotent start
        guard transactionListener == nil else { return }
        
        transactionListener = Task.detached { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                await self.handleTransactionUpdate(update)
            }
        }
    }
    
    /// Stops the background transaction listener and clears the option mapping.
    ///
    /// After calling this method:
    /// - `Transaction.updates` are no longer observed by this service
    /// - incoming updates will not be mapped to options
    /// - no further delegate callbacks are produced by background updates
    public func stopListening() {
        transactionListener?.cancel()
        transactionListener = nil
        listenerQueue.async { [weak self] in
            self?.optionByProductId = [:]
        }
    }
    
    /// Initiates a purchase for the given option.
    ///
    /// - Parameters:
    ///   - option: The host app's option describing the product to buy.
    ///   - product: The resolved StoreKit `Product` matching `option.productId`.
    /// - Returns: The raw StoreKit `Product.PurchaseResult`.
    /// - Throws: Errors thrown by StoreKit if the purchase cannot be initiated.
    public func purchase<Option: PurchasableOption>(_ option: Option, product: Product) async throws -> Product.PurchaseResult {
        IAPLogger.log("Initiating purchase for option: \(option.productId)")
        
        let result = try await product.purchase()
        await handlePurchaseResult(result, option: AnyPurchaseOption(option), product: product)
        
        return result
    }
    
    public func purchase(_ option: AnyPurchaseOption, product: Product) async throws -> Product.PurchaseResult {
        IAPLogger.log("Initiating purchase for option: \(option.productId)")

        let result = try await product.purchase()
        await handlePurchaseResult(result, option: option, product: product)

        return result
    }
    
    /// Synchronizes with the App Store and returns a snapshot of current entitlements.
    ///
    /// - Parameter options: Known options used to map `productId` → option.
    public func restorePurchases<Option: PurchasableOption>(options: [Option]) async {
        do {
            try await AppStore.sync()
            let snapshot: [Option: EntitlementState] = await fetchCurrentEntitlements(options: options)
            let erased = eraseSnapshot(snapshot)
            
            await MainActor.run {
                delegate?.transactionService(self, didFinishRestoreWith: erased)
            }
        } catch {
            IAPLogger.log("Failed to sync purchases: \(error.localizedDescription)", level: .error)
            await MainActor.run {
                delegate?.transactionService(self, didFailRestore: .systemError)
            }
        }
    }
    
    /// Builds a snapshot of current entitlements from StoreKit.
    ///
    /// This method returns a snapshot and does **not** call the delegate.
    /// It is useful for initial state derivation on app start or after a manual refresh.
    ///
    /// - Parameter options: Known options used to map `productId` → option.
    /// - Returns: A dictionary mapping each known option to its derived entitlement state.
    public func processCurrentEntitlements<Option: PurchasableOption>(options: [Option]) async -> [Option: EntitlementState] {
        await fetchCurrentEntitlements(options: options)
    }
    
    // MARK: - Private
    
    private func eraseSnapshot<Option: PurchasableOption>(
        _ snapshot: [Option: EntitlementState]
    ) -> [AnyPurchaseOption: EntitlementState] {
        Dictionary(uniqueKeysWithValues: snapshot.map { (AnyPurchaseOption($0.key), $0.value) })
    }
    
    private func fetchCurrentEntitlements<Option: PurchasableOption>(options: [Option]) async -> [Option: EntitlementState] {
        let optionById = Dictionary(uniqueKeysWithValues: options.map { ($0.productId, $0) })
        var result: [Option: EntitlementState] = [:]
        
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let tx) = verification else { continue }
            guard let option = optionById[tx.productID] else { continue }
            
            result[option] = mapEntitlement(from: tx)
        }
        
        return result
    }
    
    /// Handles a single transaction update from `Transaction.updates`.
    ///
    /// Verified transactions are mapped to `EntitlementState`, finished to prevent re-delivery,
    /// and forwarded to the delegate on the main thread. Unknown product identifiers are ignored.
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else {
            IAPLogger.log("Transaction verification failed", level: .error)
            return
        }
        
        let option: AnyPurchaseOption? = await withCheckedContinuation { cont in
            listenerQueue.async { [weak self] in
                cont.resume(returning: self?.optionByProductId[tx.productID])
            }
        }
        
        guard let option else {
            IAPLogger.log("Ignoring unknown product ID: \(tx.productID)", level: .info)
            await tx.finish()
            return
        }
        
        let entitlement = mapEntitlement(from: tx)
        await tx.finish()
        
        await MainActor.run {
            delegate?.transactionService(self, didUpdateEntitlement: entitlement, for: option)
        }
    }
    
    private func handlePurchaseResult(_ result: Product.PurchaseResult,
                                      option: AnyPurchaseOption,
                                      product: Product) async {
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let tx):
                let entitlement = mapEntitlement(from: tx)
                await tx.finish()
                
                await MainActor.run {
                    delegate?.transactionService(self, didUpdateEntitlement: entitlement, for: option)
                }
                
            case .unverified:
                IAPLogger.log("Transaction verification failed for \(product.id)", level: .error)
                await MainActor.run {
                    delegate?.transactionService(self, didFailPurchaseFor: option, error: .systemError)
                }
            }
            
        case .userCancelled:
            await MainActor.run {
                delegate?.transactionService(self, didFailPurchaseFor: option, error: .userCancelled)
            }
            
        case .pending:
            await MainActor.run {
                delegate?.transactionService(self, didSetPendingFor: option)
            }
            
        @unknown default:
            await MainActor.run {
                delegate?.transactionService(self, didFailPurchaseFor: option,
                                             error: .unknown(description: "Unknown purchase result"))
            }
        }
    }
    
    /// Maps a verified StoreKit transaction into an `EntitlementState`.
    private func mapEntitlement(from tx: Transaction) -> EntitlementState {
        if let revocationDate = tx.revocationDate {
            return .revoked(revocationDate: revocationDate)
        }
        
        if let expirationDate = tx.expirationDate {
            if expirationDate < Date() {
                return .subscriptionExpired(expirationDate: expirationDate)
            } else {
                return .subscriptionActive(expirationDate: expirationDate, transactionID: tx.id)
            }
        }
        
        return .nonConsumable(transactionID: tx.id)
    }
}
