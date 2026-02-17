//
//  TierBadge.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

/// A paywall badge used to highlight a tier.
public enum TierBadge: Hashable, Sendable {
    case bestValue
    case mostPopular
    case savePercent(Int)
    
    /// A default fallback text that can be used if the host app does not provide
    /// a fully localized custom string.
    public var defaultText: String {
        switch self {
        case .bestValue: return "purchasekit.badge.best_value".localized
        case .mostPopular: return "purchasekit.badge.most_popular".localized
        case .savePercent(let pct): return String(format: "purchasekit.badge.save_percent".localized, pct)
        }
    }
}
