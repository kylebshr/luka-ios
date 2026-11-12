//
//  WidgetAccountsTests.swift
//  LukaTests
//
//  Created by Kyle Bashour on 11/12/26.
//

import AppIntents
import Dexcom
import Foundation
import Testing
@testable import Luka

struct WidgetAccountResolutionTests {
    private let first = DexcomAccount(accountLocation: .usa)
    private let second = DexcomAccount(accountLocation: .apac)
    private let third = DexcomAccount(accountLocation: .worldwide)

    private var all: [DexcomAccount] { [first, second, third] }

    @Test func test_singleAccountIgnoresConfiguration() {
        #expect(AccountResolution.widgetAccounts(configured: [], in: [first], capacity: 2) == [first])
        #expect(AccountResolution.widgetAccounts(configured: [UUID(), UUID()], in: [first], capacity: 2) == [first])
    }

    @Test func test_noAccounts() {
        #expect(AccountResolution.widgetAccounts(configured: [first.id], in: [], capacity: 2).isEmpty)
    }

    /// Every widget added before multi-account.
    @Test func test_unsetShowsPrimaryOnly() {
        #expect(AccountResolution.widgetAccounts(configured: [], in: all, capacity: 4) == [first])
    }

    @Test func test_showsConfiguredAccountsInConfiguredOrder() {
        #expect(AccountResolution.widgetAccounts(configured: [third.id, first.id], in: all, capacity: 4) == [third, first])
    }

    @Test func test_dropsRemovedAccounts() {
        #expect(AccountResolution.widgetAccounts(configured: [UUID(), second.id], in: all, capacity: 4) == [second])
    }

    @Test func test_allRemovedFallsBackToPrimary() {
        #expect(AccountResolution.widgetAccounts(configured: [UUID(), UUID()], in: all, capacity: 4) == [first])
    }

    @Test func test_truncatesToCapacity() {
        let configured = [second.id, third.id, first.id]
        #expect(AccountResolution.widgetAccounts(configured: configured, in: all, capacity: 2) == [second, third])
        #expect(AccountResolution.widgetAccounts(configured: configured, in: all, capacity: 1) == [second])
    }

    @Test func test_ignoresDuplicates() {
        #expect(AccountResolution.widgetAccounts(configured: [second.id, second.id], in: all, capacity: 2) == [second])
    }
}

/// The `size:` of each configuration's `accounts` parameter has to be a literal,
/// so it can't reference `AccountWidgetKind.capacity(for:)`. Check what the App
/// Intents metadata processor extracted from it into the built widget
/// extensions, which is what the system's edit UI enforces.
struct WidgetAccountCapacityTests {
    private static let families: [String: IntentWidgetFamily] = [
        "systemSmall": .systemSmall,
        "systemMedium": .systemMedium,
        "systemLarge": .systemLarge,
        "accessoryRectangular": .accessoryRectangular,
        "accessoryInline": .accessoryInline,
        "accessoryCircular": .accessoryCircular,
        "accessoryCorner": .accessoryCorner,
    ]

    private static let intents: [(name: String, kind: AccountWidgetKind)] = [
        ("ReadingWidgetConfiguration", .reading),
        ("GraphWidgetConfiguration", .graph),
    ]

    private static var iOSMetadata: URL {
        Bundle.main.builtInPlugInsURL!
            .appending(path: "LukaWidget.appex/Metadata.appintents/extract.actionsdata")
    }

    @Test func test_iOSWidgetSizesMatchCapacity() throws {
        try checkSizes(in: Self.iOSMetadata)
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: watchMetadata.path)))
    func test_watchWidgetSizesMatchCapacity() throws {
        try checkSizes(in: watchMetadata)
    }

    private func checkSizes(in url: URL) throws {
        let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let actions = try #require(metadata?["actions"] as? [String: Any])

        for (name, kind) in Self.intents {
            let intent = try #require(actions[name] as? [String: Any], "\(name) missing")
            let parameters = try #require(intent["parameters"] as? [[String: Any]])
            let accounts = try #require(parameters.first { $0["name"] as? String == "accounts" })
            let typeMetadata = try #require(accounts["typeSpecificMetadata"] as? [Any])
            let sizes = try #require(
                typeMetadata
                    .compactMap { ($0 as? [String: Any])?["collectionSizes"] as? [String: Any] }
                    .first?["sizes"] as? [String: [String: Int]],
                "\(name) has no per-family sizes"
            )

            for (familyName, family) in Self.families where kind.capacity(for: family) > 1 {
                #expect(sizes[familyName] != nil, "\(name) doesn't limit \(familyName)")
            }

            for (familyName, size) in sizes {
                let family = try #require(Self.families[familyName], "Unexpected family \(familyName)")
                #expect(size["max"] == kind.capacity(for: family), "\(name) \(familyName)")
                #expect(size["min"] == 0, "\(name) \(familyName)")
            }
        }
    }
}

private let watchMetadata = Bundle.main.bundleURL
    .appending(path: "Watch/Luka.app/PlugIns/WatchWidget.appex/Metadata.appintents/extract.actionsdata")
