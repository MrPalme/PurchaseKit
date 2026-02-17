//
//  PersistenceService.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Persists purchase-related cache data using `UserDefaults`.
///
/// `PersistenceService` is intentionally best-effort:
/// - It stores a lightweight cached view of entitlements to support fast app startup UI.
/// - It does **not** replace StoreKit as the source of truth.
/// - Corrupt or unknown entries are skipped instead of failing the whole load.
///
/// Typical usage:
/// ```swift
/// let persistence = PersistenceService()
///
/// // 1) Restore cached entitlements on startup (for fast UI)
/// let cached = persistence.loadEntitlements(options: options)
///
/// // 2) After StoreKit refresh, persist the latest snapshot
/// persistence.saveEntitlements(latestEntitlementsByProductId)
/// ```
///
/// - Important:
///   Never rely on persisted entitlements for billing correctness.
///   Always re-derive entitlements from StoreKit (`Transaction.currentEntitlements`)
///   whenever possible.
public final class PersistenceService {
    
    // MARK: - Properties
    
    /// Backing store used for persistence.
    private let userDefaults: UserDefaults
    
    /// JSON encoder used to serialize wrapped entitlement states.
    private let encoder: JSONEncoder
    
    /// JSON decoder used to deserialize wrapped entitlement states.
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    /// Creates a new persistence service.
    ///
    /// - Parameter userDefaults: The `UserDefaults` container to use. Defaults to `.standard`.
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // Optional: stable encoding. Only do this if you need deterministic output.
        // self.encoder.outputFormatting = [.sortedKeys]
    }
    
    // MARK: - Entitlements
    
    /// Persists a snapshot of entitlements keyed by StoreKit product identifier.
    ///
    /// Each `EntitlementState` is encoded through `EntitlementStateWrapper` and stored
    /// as `Data` in a property list dictionary (`[String: Data]`).
    ///
    /// Entries that fail to encode are skipped to keep the operation best-effort.
    ///
    /// - Parameter entitlementsByProductId: Dictionary of `productId` → entitlement state.
    public func saveEntitlements(_ entitlementsByProductId: [String: EntitlementState]) {
        let encoded = entitlementsByProductId.compactMapValues { state -> Data? in
            do {
                return try encoder.encode(EntitlementStateWrapper(state: state))
            } catch {
                IAPLogger.log("Failed to encode entitlement: \(error.localizedDescription)", level: .warning)
                return nil
            }
        }
        
        userDefaults.set(encoded, forKey: PurchaseConstants.UserDefaultsKeys.entitlements)
        IAPLogger.log("Saved \(encoded.count) entitlements to persistent storage")
    }
    
    /// Loads cached entitlements and maps them to the provided `PurchaseOption`s.
    ///
    /// This is a convenience helper for UI models that are driven by app-defined options.
    /// The mapping uses `PurchaseOption.productId` because it is the canonical StoreKit key.
    ///
    /// Unknown product IDs or corrupt entries are ignored.
    ///
    /// - Parameter options: The options known to the host app (used for mapping).
    /// - Returns: A dictionary mapping each option to its cached entitlement state.
    public func loadEntitlements<Option: PurchaseOption>(options: [Option]) -> [Option: EntitlementState] {
        let byProductId = loadEntitlementsByProductId()
        guard byProductId.isEmpty == false else { return [:] }
        
        let optionByProductId = Dictionary(uniqueKeysWithValues: options.map { ($0.productId, $0) })
        
        var result: [Option: EntitlementState] = [:]
        for (productId, state) in byProductId {
            if let option = optionByProductId[productId] {
                result[option] = state
            }
        }
        return result
    }
    
    /// Loads cached entitlements keyed by product identifier.
    ///
    /// - Returns: A dictionary mapping `productId` → cached entitlement state.
    ///            Returns an empty dictionary if nothing has been stored yet.
    public func loadEntitlementsByProductId() -> [String: EntitlementState] {
        guard let raw = userDefaults.object(forKey: PurchaseConstants.UserDefaultsKeys.entitlements) as? [String: Data] else {
            IAPLogger.log("No cached entitlements found in storage", level: .info)
            return [:]
        }
        
        var restored: [String: EntitlementState] = [:]
        var success = 0
        var failures = 0
        
        for (productId, data) in raw {
            do {
                let wrapper = try decoder.decode(EntitlementStateWrapper.self, from: data)
                restored[productId] = wrapper.state
                success += 1
            } catch {
                IAPLogger.log("Failed to decode entitlement for \(productId): \(error.localizedDescription)", level: .warning)
                failures += 1
            }
        }
        
        IAPLogger.log("Loaded \(success) cached entitlements (\(failures) errors)", level: .info)
        return restored
    }
}
