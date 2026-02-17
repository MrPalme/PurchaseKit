//
//  PurchaseFlowState.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Represents the transient state of a purchase operation.
///
/// `PurchaseFlowState` is designed for UI concerns only:
/// - show/hide loading indicators
/// - disable/enable purchase buttons
/// - present error alerts
///
/// It does **not** describe long-lived access to features. For that, use an entitlement model
/// (e.g. `EntitlementState`) derived from StoreKit transactions/current entitlements.
///
/// - Important:
///   This state should not be persisted. It should be reset as appropriate (typically to `.idle`)
///   after a purchase attempt finishes, and the UI should rely on entitlements to decide
///   whether features are unlocked.
public enum PurchaseFlowState: Equatable, Sendable {
    
    /// No purchase operation is currently running.
    ///
    /// Use this state to render the default UI (buttons enabled, no spinners).
    case idle
    
    /// A purchase request is currently being processed.
    ///
    /// Use this state to disable purchase UI and show a loading indicator.
    case purchasing
    
    /// The purchase is awaiting external approval.
    ///
    /// Common scenarios include “Ask to Buy” / parental approval or other App Store
    /// approval flows. The final outcome will arrive asynchronously via StoreKit updates.
    case pending
    
    /// The last purchase attempt failed.
    ///
    /// Use the associated `PurchaseError` to present a user-friendly message and
    /// optionally offer recovery actions (e.g. retry, check connection, restore purchases).
    case failed(PurchaseError)
}
