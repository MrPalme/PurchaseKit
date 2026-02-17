//
//  Feature.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

/// Describes a user-facing capability that can be advertised on a paywall or feature list.
///
/// `Feature` is intentionally app-agnostic:
/// - The host app defines the concrete features (e.g. `cloudBackup`, `advancedFilters`).
/// - The library can render these features in shared UI components (lists, cards, etc.).
///
/// Conforming types should provide stable identifiers and localized strings that are
/// safe to display directly in the UI.
public protocol Feature: Hashable, Sendable {
    
    /// A stable identifier for the feature (used for diffing, analytics, and persistence).
    ///
    /// Keep this value stable across app versions to avoid breaking references.
    var id: String { get }
    
    /// A localized, short display name for the feature.
    ///
    /// Example: "Cloud Backup", "Advanced Filters".
    var localizedName: String { get }
    
    /// A localized, longer description that explains the feature in more detail.
    ///
    /// Example: "Sync your data across devices and restore anytime."
    var localizeDescription: String { get }
    
}
