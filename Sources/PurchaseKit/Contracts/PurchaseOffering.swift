//
//  PurchaseOffering.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

/// Groups multiple purchase options under a single plan/offering.
///
/// Typical examples:
/// - "Pro" offering with monthly/yearly options
/// - "Premium" offering with its own subscription options
/// - "Lifetime" offering with a single non-consumable option
public protocol PurchaseOffering: Hashable, Sendable {
    
    /// Stable identifier used for grouping and selection logic.
    var id: String { get }
    
    /// Title shown in UI (localized by the host app).
    var title: String { get }
    
    /// Optional description shown in UI (localized by the host app).
    var description: String? { get }
    
    /// Feature list advertised for this offering (shared across all its options).
    var features: [any Feature] { get }
    
    /// Sorting order for UI presentation (lower values appear first).
    var sortOrder: Int { get }
}
