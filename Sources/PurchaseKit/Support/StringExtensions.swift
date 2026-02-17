//
//  StringExtensions.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

extension String {
    
    /// Returns the localized value for the receiver using `NSLocalizedString`.
    ///
    /// This is a convenience accessor commonly used with string keys:
    /// ```swift
    /// Text("purchase_restore_button_title".localized)
    /// ```
    ///
    /// - Important:
    ///   When used inside a Swift Package, `NSLocalizedString` resolves strings from the
    ///   main bundle by default. If you ship localized strings inside the package,
    ///   prefer a bundle-aware helper (e.g. `NSLocalizedString(_:tableName:bundle:...)`)
    ///   targeting `Bundle.module`.
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns a normalized version of the string suitable for search and matching.
    ///
    /// The normalization:
    /// - removes diacritics (e.g. "ä" → "a")
    /// - ignores case (e.g. "Pro" → "pro")
    /// - trims leading and trailing whitespace/newlines
    ///
    /// This is useful for performing case-insensitive, accent-insensitive comparisons
    /// without altering the original display string.
    ///
    /// Example:
    /// ```swift
    /// let query = "  münchen ".normalizedForSearch()   // "munchen"
    /// let value = "Muenchen".normalizedForSearch()     // "muenchen"
    /// ```
    ///
    /// - Returns: The normalized string.
    func normalizedForSearch() -> String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
