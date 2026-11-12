//
//  MultiAccountLiveActivityTests.swift
//  LukaTests
//
//  Created by Kyle Bashour on 11/12/26.
//

import Foundation
import Testing
@testable import Dexcom
@testable import Luka

struct ReadingAttributesDecodingTests {

    /// Activities from older builds, and server push-to-start restarts replaying their
    /// registered attributes, carry only the range.
    @Test func test_decodesAttributesWithoutAccount() throws {
        let json = Data(#"{"range":"threeHours"}"#.utf8)
        let attributes = try JSONDecoder().decode(ReadingAttributes.self, from: json)
        #expect(attributes.range == .threeHours)
        #expect(attributes.accountID == nil)
        #expect(attributes.accountName == nil)
    }

    @Test func test_roundTripsAccount() throws {
        let id = UUID()
        let attributes = ReadingAttributes(range: .sixHours, accountID: id, accountName: "Alex")
        let decoded = try JSONDecoder().decode(ReadingAttributes.self, from: JSONEncoder().encode(attributes))
        #expect(decoded.range == .sixHours)
        #expect(decoded.accountID == id)
        #expect(decoded.accountName == "Alex")
    }

    /// A single-account activity must encode exactly as before, so the server (and
    /// older builds it replays to) see no new keys.
    @Test func test_omitsAbsentAccountWhenEncoding() throws {
        let value = try JSONValue(encoding: ReadingAttributes(range: .threeHours))
        #expect(value == .object(["range": .string("threeHours")]))
    }
}

struct AccountResolutionTests {
    private let first = DexcomAccount(accountLocation: .usa)
    private let second = DexcomAccount(accountLocation: .apac)
    private let legacy = DexcomAccount(id: AccountStore.legacyAccountID, accountLocation: .usa)

    // MARK: Widgets

    @Test func test_widgetUnsetUsesPrimary() {
        #expect(AccountResolution.accountOrPrimary(for: nil, in: [first, second]) == first)
    }

    @Test func test_widgetUsesConfiguredAccount() {
        #expect(AccountResolution.accountOrPrimary(for: second.id, in: [first, second]) == second)
    }

    @Test func test_widgetRemovedAccountFallsBackToPrimary() {
        #expect(AccountResolution.accountOrPrimary(for: UUID(), in: [first, second]) == first)
    }

    @Test func test_widgetSignedOut() {
        #expect(AccountResolution.accountOrPrimary(for: second.id, in: []) == nil)
    }

    // MARK: Live Activities

    @Test func test_activityUsesItsAccount() {
        #expect(AccountResolution.liveActivityOwner(for: second.id, in: [first, second]) == .account(second))
    }

    @Test func test_activityWithoutAccountUsesPrimary() {
        #expect(AccountResolution.liveActivityOwner(for: nil, in: [first, second]) == .account(first))
    }

    /// The pre-multi-account build registered under the account the migration
    /// turned into the legacy one, even if it's no longer first.
    @Test func test_activityWithoutAccountPrefersLegacyAccount() {
        #expect(AccountResolution.liveActivityOwner(for: nil, in: [first, legacy]) == .account(legacy))
    }

    @Test func test_activityForRemovedAccountIsOrphaned() {
        #expect(AccountResolution.liveActivityOwner(for: UUID(), in: [first, second]) == .orphaned)
    }

    /// An empty list may just mean the keychain is locked; never treat that as orphaned.
    @Test func test_activityWithNoAccountsIsUnavailable() {
        #expect(AccountResolution.liveActivityOwner(for: second.id, in: []) == .unavailable)
        #expect(AccountResolution.liveActivityOwner(for: nil, in: []) == .unavailable)
    }
}

struct StartLiveActivityErrorTests {
    private struct DexcomDown: Error {}

    @Test func test_prefersRealFailureOverUnreadableCredentials() {
        let errors: [(any Error)?] = [StartLiveActivityIntent.LiveActivityError.loggedOut, DexcomDown()]
        #expect(StartLiveActivityIntent.mostUsefulError(errors) is DexcomDown)
    }

    @Test func test_usesFirstFailureInAccountOrder() {
        let errors: [(any Error)?] = [nil, StartLiveActivityIntent.LiveActivityError.loggedOut]
        #expect(StartLiveActivityIntent.mostUsefulError(errors) is StartLiveActivityIntent.LiveActivityError)
        #expect(StartLiveActivityIntent.mostUsefulError([nil, nil]) == nil)
    }
}

struct LiveActivityNameTests {

    @Test func test_prefersDisplayName() {
        #expect(StartLiveActivityIntent.activityName(displayName: "Alex", username: "alex.smith@example.com") == "Alex")
    }

    @Test func test_dropsEmailDomainFromUsername() {
        #expect(StartLiveActivityIntent.activityName(displayName: "", username: "alex.smith@example.com") == "alex.smith")
        #expect(StartLiveActivityIntent.activityName(displayName: "", username: "alexsmith") == "alexsmith")
    }
}

struct QueuedClientEventTests {

    /// Events queued by an older build were bare events; they must still decode.
    @Test func test_decodesEventQueuedByOlderBuild() throws {
        let event = ClientEventRequest.Event(name: "app_launch", occurredAt: 1, activityID: "a", attributes: ["k": "v"])
        let decoded = try JSONDecoder().decode(QueuedClientEvent.self, from: JSONEncoder().encode(event))
        #expect(decoded.event == event)
        #expect(decoded.accountID == nil)
    }

    @Test func test_roundTripsAccount() throws {
        let queued = QueuedClientEvent(
            event: .init(name: "token_sent", occurredAt: 2, activityID: "b", attributes: nil),
            accountID: UUID()
        )
        let decoded = try JSONDecoder().decode(QueuedClientEvent.self, from: JSONEncoder().encode(queued))
        #expect(decoded == queued)
    }
}
