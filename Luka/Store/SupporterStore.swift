//
//  SupporterStore.swift
//  Luka
//
//  Created by Claude on 9/7/26.
//

import Defaults
import Foundation
import StoreKit
import TelemetryDeck

/// The optional monthly "supporter" subscriptions. All tiers live in one App
/// Store subscription group, so switching between them is an upgrade or
/// downgrade rather than a second subscription. Ordered lowest to highest.
enum SupporterTier: String, CaseIterable, Identifiable {
    case supporter = "com.kylebashour.Glimpse.supporter.monthly"
    case superSupporter = "com.kylebashour.Glimpse.supporter.super.monthly"
    case megaSupporter = "com.kylebashour.Glimpse.supporter.mega.monthly"

    var id: String { rawValue }

    var name: LocalizedStringResource {
        switch self {
        case .supporter: "Glucose Tab"
        case .superSupporter: "Juice Box"
        case .megaSupporter: "The Whole Fridge"
        }
    }

    /// Opening line of the thank-you copy, phrased to read naturally with the name.
    var thanks: LocalizedStringResource {
        switch self {
        case .supporter: "Thanks for the glucose tab!"
        case .superSupporter: "Thanks for the juice box!"
        case .megaSupporter: "Thanks for the whole fridge!"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .supporter: "Cheap but fast-acting."
        case .superSupporter: "A classic."
        case .megaSupporter: "You're overtreating, but we're here for it."
        }
    }

    var systemImage: String {
        switch self {
        case .supporter: "pill.fill"
        case .superSupporter: "waterbottle.fill"
        case .megaSupporter: "refrigerator.fill"
        }
    }

    /// Shown before the App Store products load.
    var fallbackDisplayPrice: String {
        switch self {
        case .supporter: "99¢"
        case .superSupporter: "$2.99"
        case .megaSupporter: "$9.99"
        }
    }
}

/// Manages the supporter subscriptions, which help pay for the server that
/// powers Live Activities. They unlock nothing; it's a tip jar.
@Observable @MainActor
final class SupporterStore {
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicyURL = URL(string: "https://pitou.tech/luka-privacy")!

    private(set) var products: [SupporterTier: Product] = [:]
    private(set) var currentTier: SupporterTier?
    private(set) var isPurchasing = false
    var purchaseError: String?

    var isSupporter: Bool {
        currentTier != nil
    }

    /// The cheapest tier's price, for "from 99¢/month" copy.
    var lowestDisplayPrice: String {
        displayPrice(for: .supporter)
    }

    func displayPrice(for tier: SupporterTier) -> String {
        guard let product = products[tier] else {
            return tier.fallbackDisplayPrice
        }

        // Sub-dollar US prices read better as cents ("99¢" rather than "$0.99").
        // Other storefronts keep Apple's localized string.
        if product.priceFormatStyle.currencyCode == "USD", product.price < 1 {
            let cents = NSDecimalNumber(decimal: product.price * 100).intValue
            return "\(cents)¢"
        }

        return product.displayPrice
    }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        // Start from the last verified entitlement so the UI doesn't flash the
        // non-supporter state while StoreKit checks current entitlements.
        currentTier = Defaults[.cachedSupporterTier].flatMap(SupporterTier.init(rawValue:))

        // Transactions can arrive outside a purchase flow (renewals, Ask to Buy
        // approvals, purchases on another device). Finish them and refresh.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }

        Task {
            await load()
        }
    }

    func load() async {
        await refreshEntitlement()

        do {
            let loaded = try await Product.products(for: SupporterTier.allCases.map(\.rawValue))
            var products: [SupporterTier: Product] = [:]
            for product in loaded {
                if let tier = SupporterTier(rawValue: product.id) {
                    products[tier] = product
                }
            }
            self.products = products
        } catch {
            print("Failed to load supporter products: \(error)")
        }
    }

    func refreshEntitlement() async {
        var active: SupporterTier?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let tier = SupporterTier(rawValue: transaction.productID)
            else {
                continue
            }

            // Only one subscription in a group is active at a time, but be
            // defensive and keep the highest tier if several show up.
            if active == nil || tier > active! {
                active = tier
            }
        }

        currentTier = active
        Defaults[.cachedSupporterTier] = active?.rawValue
    }

    func purchase(_ tier: SupporterTier, source: String) async {
        guard let product = products[tier], !isPurchasing else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        let parameters = ["source": source, "tier": tier.rawValue]

        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlement()
                TelemetryDeck.signal("Support.purchased", parameters: parameters)
            case .pending:
                TelemetryDeck.signal("Support.pending", parameters: parameters)
            case .userCancelled:
                TelemetryDeck.signal("Support.cancelled", parameters: parameters)
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            TelemetryDeck.signal("Support.failed", parameters: parameters)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = error.localizedDescription
        }

        await refreshEntitlement()
        TelemetryDeck.signal("Support.restored", parameters: ["isSupporter": isSupporter.description])
    }
}

extension SupporterTier: Comparable {
    static func < (lhs: SupporterTier, rhs: SupporterTier) -> Bool {
        let all = SupporterTier.allCases
        return all.firstIndex(of: lhs)! < all.firstIndex(of: rhs)!
    }
}
