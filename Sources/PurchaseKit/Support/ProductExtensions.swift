//
//  ProductExtensions.swift
//  PurchaseKit
//
//  Created by Markus Mock on 16.02.26.
//

import Foundation
import StoreKit

/// Convenience helpers for displaying StoreKit 2 `Product` information in PurchaseKit UIs.
///
/// The extensions focus on:
/// - subscription period access
/// - monthly equivalent price calculation
/// - savings percentage calculation
/// - introductory free trial detection/formatting
///
/// - Important:
///   All localized strings are resolved from `Bundle.module` via `PKL10n`.
public extension Product {
    
    // MARK: - Subscription
    
    /// Returns the subscription period if the product is a subscription.
    var subscriptionPeriod: Product.SubscriptionPeriod? {
        subscription?.subscriptionPeriod
    }
    
    /// Returns `true` if the product represents any kind of subscription.
    var isSubscription: Bool { subscription != nil }
    
    // MARK: - Monthly Equivalent
    
    /// Returns the monthly equivalent price as localized currency text.
    ///
    /// - Note:
    ///   Uses the product's `priceFormatStyle.locale` to match the App Store currency format.
    ///
    /// - Returns: A localized currency string (e.g. "1,50 €") or `nil` if formatting fails.
    var monthlyEquivalentPriceLocalized: String? {
        let monthly = monthlyEquivalentPriceDecimal
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceFormatStyle.locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: monthly))
    }
    
    /// Returns the price normalized to "per month" for subscription products.
    ///
    /// The conversion uses an average month length (365/12 days) to avoid the
    /// "4 weeks == 1 month" approximation.
    ///
    /// - Returns:
    ///   - For subscriptions: monthly equivalent `Decimal` price.
    ///   - For non-subscriptions: `price` (treated as a one-time purchase).
    var monthlyEquivalentPriceDecimal: Decimal {
        guard let subscription else { return price }
        
        let period = subscription.subscriptionPeriod
        
        // Average month length in days (≈ 30.4167).
        let avgDaysPerMonth: Decimal = 365 / 12
        
        let monthsInPeriod: Decimal = {
            let value = Decimal(period.value)
            switch period.unit {
            case .day:
                return value / avgDaysPerMonth
            case .week:
                return (value * 7) / avgDaysPerMonth
            case .month:
                return value
            case .year:
                return value * 12
            @unknown default:
                return 1
            }
        }()
        
        // Defensive: avoid divide-by-zero.
        guard monthsInPeriod > 0 else { return price }
        return price / monthsInPeriod
    }
    
    /// Computes how much cheaper `self` is (per month) compared to `baseline` (per month).
    ///
    /// - Parameter baseline: The product used as the comparison baseline.
    /// - Returns:
    ///   Whole-number discount percentage (rounded down), or `nil` if either product
    ///   is not a subscription or the baseline monthly price is zero.
    func savingsPercentage(comparedTo baseline: Product) -> Int? {
        guard isSubscription, baseline.isSubscription else { return nil }
        
        let baselineMonthly = baseline.monthlyEquivalentPriceDecimal
        guard baselineMonthly > 0 else { return nil }
        
        let thisMonthly = monthlyEquivalentPriceDecimal
        let rawPercent = ((baselineMonthly - thisMonthly) / baselineMonthly) * 100
        
        // Clamp negatives first, then floor (round down for positive values).
        let clamped = max(0, rawPercent)
        var floored = Decimal()
        var tmp = clamped
        NSDecimalRound(&floored, &tmp, 0, .down)
        
        return NSDecimalNumber(decimal: floored).intValue
    }
    
    // MARK: - Intro Offer / Free Trial
    
    /// Returns `true` when the product exposes an introductory free trial offer.
    var hasFreeTrial: Bool {
        subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
    
    /// Returns a localized text for the free trial period, e.g. "7 days free".
    ///
    /// - Returns: A localized trial text or `nil` if no free trial is available.
    ///
    /// - Note:
    ///   Localization keys used:
    ///   - `purchasekit_trial_free_format` (e.g. "%d %@ free")
    ///   - period unit keys via `Product.SubscriptionPeriod.Unit` helpers
    var freeTrialPeriodText: String? {
        guard let offer = subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial
        else { return nil }
        
        let value = offer.period.value
        let unitText = offer.period.unit.shortUnitText(value: value)
        return PKL10n.format("purchasekit_trial_free_format", value, unitText)
    }
    
    /// Returns a localized billing interval suffix, e.g. "/ month" or "/ year".
    ///
    /// - Returns: A localized suffix or `nil` for non-subscription products.
    ///
    /// - Note:
    ///   Localization key used:
    ///   - `purchasekit_billing_suffix_format` (e.g. "/ %@")
    var billingPeriodText: String? {
        guard let period = subscription?.subscriptionPeriod else { return nil }
        return PKL10n.format("purchasekit_billing_suffix_format", period.unit.intervalDisplayName)
    }
}

// MARK: - Product.SubscriptionPeriod.Unit

public extension Product.SubscriptionPeriod.Unit {
    
    /// A localized display name for the recurring interval (e.g. "month", "year").
    ///
    /// Localization keys used:
    /// - `purchasekit_period_day`
    /// - `purchasekit_period_week`
    /// - `purchasekit_period_month`
    /// - `purchasekit_period_year`
    var intervalDisplayName: String {
        switch self {
        case .day:   return PKL10n.string("purchasekit_period_day")
        case .week:  return PKL10n.string("purchasekit_period_week")
        case .month: return PKL10n.string("purchasekit_period_month")
        case .year:  return PKL10n.string("purchasekit_period_year")
        @unknown default:
            return PKL10n.string("purchasekit_period_generic")
        }
    }
    
    /// Returns a short localized unit text matching the numeric value (singular/plural).
    ///
    /// This is implemented via localization keys to stay language-agnostic.
    ///
    /// Localization keys used:
    /// - `purchasekit_unit_day_singular`, `purchasekit_unit_day_plural`
    /// - `purchasekit_unit_week_singular`, `purchasekit_unit_week_plural`
    /// - `purchasekit_unit_month_singular`, `purchasekit_unit_month_plural`
    /// - `purchasekit_unit_year_singular`, `purchasekit_unit_year_plural`
    ///
    /// - Parameter value: The numeric unit count (used for singular/plural selection).
    /// - Returns: Localized unit label for the given value.
    func shortUnitText(value: Int) -> String {
        let isSingular = (value == 1)
        switch self {
        case .day:
            return PKL10n.string(isSingular ? "purchasekit_unit_day_singular" : "purchasekit_unit_day_plural")
        case .week:
            return PKL10n.string(isSingular ? "purchasekit_unit_week_singular" : "purchasekit_unit_week_plural")
        case .month:
            return PKL10n.string(isSingular ? "purchasekit_unit_month_singular" : "purchasekit_unit_month_plural")
        case .year:
            return PKL10n.string(isSingular ? "purchasekit_unit_year_singular" : "purchasekit_unit_year_plural")
        @unknown default:
            return PKL10n.string(isSingular ? "purchasekit_unit_generic_singular" : "purchasekit_unit_generic_plural")
        }
    }
}

// MARK: - Product.SubscriptionPeriod

public extension Product.SubscriptionPeriod {
    
    /// Returns a localized description for the subscription period, e.g. "1 month".
    ///
    /// Localization key used:
    /// - `purchasekit_period_value_format` (e.g. "%d %@")
    var localizedDescription: String {
        PKL10n.format("purchasekit_period_value_format", value, unit.shortUnitText(value: value))
    }
}
