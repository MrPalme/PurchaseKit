//
//  Localization.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Lightweight localization helper for PurchaseKit.
///
/// Swift Packages must resolve localized strings from `Bundle.module`.
/// This helper keeps localization calls consistent across the library.
enum PKL10n {
    
    /// Returns a localized string for the given key from `Bundle.module`.
    ///
    /// - Parameters:
    ///   - key: The localization key.
    ///   - table: Optional strings table name. Defaults to `nil` (Localizable.strings).
    /// - Returns: The localized string from the package bundle.
    static func string(_ key: String, table: String? = nil) -> String {
        NSLocalizedString(key, tableName: table, bundle: .module, comment: "")
    }
    
    /// Returns a localized, formatted string using the given arguments.
    ///
    /// - Parameters:
    ///   - key: The localization key.
    ///   - args: Format arguments applied via `String(format:)`.
    /// - Returns: A formatted, localized string.
    static func format(_ key: String, _ args: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, locale: .current, arguments: args)
    }
}
