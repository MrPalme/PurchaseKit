//
//  IAPLogger.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Centralized logging utility for IAP operations.
///
/// Provides a simple wrapper around the custom `print` extension with
/// severity-based prefixes. Messages are routed through the print extension
/// which handles debug/release behavior and file logging automatically.
///
final class IAPLogger {
    
    /// Logging severity used to categorize messages with visual prefixes.
    enum LogLevel {
        /// Informational messages for normal application flow.
        case info
        /// Potential issues that do not interrupt the flow but should be reviewed.
        case warning
        /// Critical failures or unrecoverable states that require attention.
        case error
    }
    
    /// Category identifier for IAP-related logs.
    ///
    /// - Note: Used as prefix in log messages for filtering and identification.
    ///
    private static let category = "InAppPurchase"
    
    /// Logs a message with the specified severity level.
    ///
    /// Routes messages through the custom `print` extension which handles
    /// debug/release behavior, file logging, and console output automatically.
    /// Each severity level gets a distinctive emoji prefix for better readability.
    ///
    /// - Parameters:
    ///   - message: The message to log.
    ///   - level: The severity level for this message. Defaults to `.info`.
    ///
    static func log(_ message: String, level: LogLevel = .info) {
        let prefix: String
        
        switch level {
        case .info: prefix = "ℹ️"
        case .warning: prefix = "⚠️"
        case .error: prefix = "❌"
        }
        
        print("[\(category)] \(prefix) \(message)")
    }
}
