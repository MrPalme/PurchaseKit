//
//  ProductService.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation
import StoreKit

/// Loads and caches StoreKit 2 `Product` metadata for `PurchaseOption`s.
///
/// `ProductService` fetches product information from the App Store (price, display name,
/// subscription period, etc.) using StoreKit 2 and caches the results to avoid redundant
/// network calls.
///
/// The service is host-app agnostic: callers provide the relevant product identifiers
/// through `PurchaseOption.productId`.
///
/// Usage pattern:
/// ```swift
/// let productService = ProductService()
/// let productsById = try await productService.loadProducts(for: options)
/// let monthly = productService.product(for: options[0])
/// ```
///
/// - Important: Products must be loaded before initiating purchases.
/// - Note: This service only loads product metadata. It does not perform purchases or entitlement checks.
public final class ProductService: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Represents the cache policy for product loading.
    public enum CachePolicy: Sendable {
        
        /// Returns cached values if available; missing products are fetched.
        case useCache
        /// Always re-fetches all requested products from the App Store (ignoring cached entries).
        case reloadIgnoringCache
    }
    
    // MARK: - Private State
    
    /// Cache keyed by StoreKit product identifier (`Product.id`).
    private var cacheByProductId: [String: Product] = [:]
    
    /// Serial queue to isolate cache mutations and reads.
    private let cacheQueue = DispatchQueue(label: "com.purchasekit.product.cache", qos: .utility)
    
    // MARK: - Initialization
    
    public init() { }
    
    // MARK: - Public API
    
    /// Loads StoreKit products for the given options and updates the internal cache.
    ///
    /// - Parameters:
    ///   - options: The purchase options to load products for.
    ///   - policy: Cache strategy. Default is `.useCache`.
    /// - Returns: A dictionary mapping `productId` → `Product` for successfully loaded products.
    /// - Throws: `PurchaseError` if StoreKit product loading fails.
    ///
    /// - Note:
    ///   Invalid or missing product identifiers are not considered fatal by StoreKit 2.
    ///   If a product id does not resolve, it will simply be absent from the returned dictionary.
    @discardableResult
    public func loadProducts<Option: PurchaseOption>(
        for options: [Option],
        policy: CachePolicy = .useCache
    ) async throws -> [String: Product] {
        let ids = Array(Set(options.map { $0.productId })) // de-dup
        
        switch policy {
        case .useCache:
            let missing = cacheQueue.sync { ids.filter { cacheByProductId[$0] == nil } }
            if missing.isEmpty {
                IAPLogger.log("ProductService: returning cached products for \(ids.count) ids", level: .info)
                return cacheQueue.sync { Dictionary(uniqueKeysWithValues: ids.compactMap { id in cacheByProductId[id].map { (id, $0) } }) }
            }
            return try await fetchAndCache(productIds: missing, includeFromCache: ids)
            
        case .reloadIgnoringCache:
            return try await fetchAndCache(productIds: ids, includeFromCache: ids)
        }
    }
    
    /// Loads StoreKit products for the given type-erased options and updates the internal cache.
    ///
    /// This overload exists so higher layers can work purely with `AnyPurchaseOption`
    /// while keeping the generic `PurchaseOption` API for host apps.
    ///
    /// - Parameters:
    ///   - options: The type-erased purchase options to load products for.
    ///   - policy: Cache strategy. Default is `.useCache`.
    /// - Returns: A dictionary mapping `productId` → `Product` for successfully loaded products.
    /// - Throws: `PurchaseError` if StoreKit product loading fails.
    @discardableResult
    public func loadProducts(
        for options: [AnyPurchaseOption],
        policy: CachePolicy = .useCache
    ) async throws -> [String: Product] {
        let ids = Array(Set(options.map { $0.productId }))
        return try await loadProducts(forProductIds: ids, policy: policy)
    }
    
    /// Loads StoreKit products for the given product identifiers and updates the internal cache.
    ///
    /// - Parameters:
    ///   - productIds: The StoreKit product identifiers to fetch.
    ///   - policy: Cache strategy.
    /// - Returns: A dictionary mapping `productId` → `Product`.
    private func loadProducts(
        forProductIds productIds: [String],
        policy: CachePolicy
    ) async throws -> [String: Product] {
        switch policy {
        case .useCache:
            let missing = cacheQueue.sync { productIds.filter { cacheByProductId[$0] == nil } }
            if missing.isEmpty {
                IAPLogger.log("ProductService: returning cached products for \(productIds.count) ids", level: .info)
                return cacheQueue.sync {
                    Dictionary(uniqueKeysWithValues: productIds.compactMap { id in
                        cacheByProductId[id].map { (id, $0) }
                    })
                }
            }
            return try await fetchAndCache(productIds: missing, includeFromCache: productIds)

        case .reloadIgnoringCache:
            cacheQueue.sync {
                for id in productIds { cacheByProductId[id] = nil }
            }
            return try await fetchAndCache(productIds: productIds, includeFromCache: productIds)
        }
    }
    
    /// Returns the cached StoreKit product for the given option, if available.
    ///
    /// - Parameter option: The option whose StoreKit product should be returned.
    /// - Returns: The cached `Product` or `nil` if it has not been loaded yet.
    public func product<Option: PurchaseOption>(for option: Option) -> Product? {
        cacheQueue.sync { cacheByProductId[option.productId] }
    }
    
    /// Returns all currently cached products.
    ///
    /// - Returns: An array of cached `Product` values.
    public func cachedProducts() -> [Product] {
        cacheQueue.sync { Array(cacheByProductId.values) }
    }
    
    /// Clears the internal product cache.
    public func clearCache() {
        cacheQueue.sync {
            cacheByProductId.removeAll()
        }
    }
    
    // MARK: - Private
    
    private func fetchAndCache(productIds: [String], includeFromCache allRequestedIds: [String]) async throws -> [String: Product] {
        do {
            let fetched = try await Product.products(for: productIds)
            
            cacheQueue.sync {
                for p in fetched {
                    cacheByProductId[p.id] = p
                }
            }
            
            IAPLogger.log("ProductService: loaded \(fetched.count) products (requested \(productIds.count))")
            
            // Build final result for all requested ids (cache + fetched)
            return cacheQueue.sync {
                Dictionary(uniqueKeysWithValues: allRequestedIds.compactMap { id in
                    cacheByProductId[id].map { (id, $0) }
                })
            }
        } catch {
            IAPLogger.log("ProductService: failed to load products: \(error.localizedDescription)", level: .error)
            
            // Keep your mapping simple & consistent with your existing errors.
            // If you want, we can map StoreKit errors more granularly later.
            throw PurchaseError.networkError
        }
    }
}
