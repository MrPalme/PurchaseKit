//
//  EntitlementStateWrapper.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation

/// Codable bridge for `EntitlementState`.
///
/// This wrapper serializes `EntitlementState` into a stable JSON representation
/// without requiring the enum itself to conform to `Codable`.
struct EntitlementStateWrapper: Codable {
    
    /// The decoded `EntitlementState` represented by this wrapper.
    let state: EntitlementState
    
    /// Keys used to encode/decode the wrapper payload.
    enum CodingKeys: String, CodingKey {
        case type
        case transactionID
        case expirationDate
        case revocationDate
    }
    
    /// Creates a wrapper for encoding.
    init(state: EntitlementState) {
        self.state = state
    }
    
    /// Decodes a wrapped `EntitlementState`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        
        switch type {
        case "inactive":
            state = .inactive
            
        case "nonConsumable":
            let id = try c.decode(UInt64.self, forKey: .transactionID)
            state = .nonConsumable(transactionID: id)
            
        case "subscriptionActive":
            let exp = try c.decode(Date.self, forKey: .expirationDate)
            let id = try c.decode(UInt64.self, forKey: .transactionID)
            state = .subscriptionActive(expirationDate: exp, transactionID: id)
            
        case "subscriptionExpired":
            let exp = try c.decode(Date.self, forKey: .expirationDate)
            state = .subscriptionExpired(expirationDate: exp)
            
        case "revoked":
            let date = try c.decode(Date.self, forKey: .revocationDate)
            state = .revoked(revocationDate: date)
            
        default:
            // Best-effort fallback for forward compatibility.
            state = .inactive
        }
    }
    
    /// Encodes the wrapped `EntitlementState`.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        
        switch state {
        case .inactive:
            try c.encode("inactive", forKey: .type)
            
        case .nonConsumable(let transactionID):
            try c.encode("nonConsumable", forKey: .type)
            try c.encode(transactionID, forKey: .transactionID)
            
        case .subscriptionActive(let expirationDate, let transactionID):
            try c.encode("subscriptionActive", forKey: .type)
            try c.encode(expirationDate, forKey: .expirationDate)
            try c.encode(transactionID, forKey: .transactionID)
            
        case .subscriptionExpired(let expirationDate):
            try c.encode("subscriptionExpired", forKey: .type)
            try c.encode(expirationDate, forKey: .expirationDate)
            
        case .revoked(let revocationDate):
            try c.encode("revoked", forKey: .type)
            try c.encode(revocationDate, forKey: .revocationDate)
        }
    }
}
