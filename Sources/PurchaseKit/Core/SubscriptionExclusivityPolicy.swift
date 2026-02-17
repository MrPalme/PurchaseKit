//
//  SubscriptionExclusivityPolicy.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Enforces subscription exclusivity within the same offering.
///
/// If an option becomes actively entitled and it belongs to an offering (`offeringId != nil`),
/// all other options with the same offering are set to `.inactive`.
///
/// - Important: This policy never touches options without an `offeringId`
///   (e.g. lifetime non-consumables).
enum SubscriptionExclusivityPolicy {

    /// Applies exclusivity rules to an entitlement snapshot.
    ///
    /// - Parameters:
    ///   - current: Current entitlement snapshot.
    ///   - incoming: Newly derived entitlements (e.g., from a transaction update).
    /// - Returns: Reduced entitlement snapshot with exclusivity enforced.
    static func reduce(
        current: [AnyPurchaseOption: EntitlementState],
        incoming: [AnyPurchaseOption: EntitlementState]
    ) -> [AnyPurchaseOption: EntitlementState] {

        var next = current
        // Apply incoming first
        for (opt, ent) in incoming {
            next[opt] = ent
        }

        // For every active subscription option, deactivate siblings in same offering.
        let activeSubscriptions = next.filter { (opt, ent) in
            ent.isActive && opt.purchaseType == .autoRenewableSubscription && opt.offeringId != nil
        }

        for (activeOpt, _) in activeSubscriptions {
            guard let group = activeOpt.offeringId else { continue }

            for (opt, ent) in next {
                guard opt != activeOpt else { continue }
                guard opt.purchaseType == .autoRenewableSubscription else { continue }
                guard opt.offeringId == group else { continue }

                if ent.isActive {
                    next[opt] = .inactive
                }
            }
        }

        return next
    }
}
