//
//  LukaTests.swift
//  LukaTests
//
//  Created by Kyle Bashour on 1/17/26.
//

import Defaults
import Foundation
import Testing
@testable import Luka
@testable import Dexcom

struct DateTests {

    @Test func test_isExpired() async throws {
        let reading = GlucoseReading(value: 100, trend: .flat, date: .now.addingTimeInterval(-10 * 60))
        #expect(!reading.isExpired(at: .now))
        #expect(reading.isExpired(at: .now, expiration: .init(value: 5, unit: .minutes)))
    }

}

struct SupportPromptTests {

    @Test func test_doesNotShowBeforeSecondStart() {
        #expect(!SupportPrompt.shouldShow(startCount: 0, isSupporter: false, lastPromptDate: nil))
        #expect(!SupportPrompt.shouldShow(startCount: 1, isSupporter: false, lastPromptDate: nil))
    }

    @Test func test_showsOnSecondStart() {
        #expect(SupportPrompt.shouldShow(startCount: 2, isSupporter: false, lastPromptDate: nil))
        #expect(SupportPrompt.shouldShow(startCount: 50, isSupporter: false, lastPromptDate: nil))
    }

    @Test func test_neverShowsForSupporters() {
        #expect(!SupportPrompt.shouldShow(startCount: 10, isSupporter: true, lastPromptDate: nil))
    }

    @Test func test_repromptsAfterInterval() {
        let now = Date.now
        let recent = now.addingTimeInterval(-SupportPrompt.repromptInterval + 60)
        let old = now.addingTimeInterval(-SupportPrompt.repromptInterval - 60)

        #expect(!SupportPrompt.shouldShow(startCount: 5, isSupporter: false, lastPromptDate: recent, now: now))
        #expect(SupportPrompt.shouldShow(startCount: 5, isSupporter: false, lastPromptDate: old, now: now))
    }

}

struct BackendRolloutTests {

    @Test func test_automaticFollowsRollout() {
        #expect(Backend.resolve(preference: .automatic, rollout: 0.5, bucket: 0.49) == .cloudflare)
        #expect(Backend.resolve(preference: .automatic, rollout: 0.5, bucket: 0.5) == .fly)
        #expect(Backend.resolve(preference: .automatic, rollout: 0, bucket: 0) == .fly)
        #expect(Backend.resolve(preference: .automatic, rollout: 1, bucket: 0.999) == .cloudflare)
    }

    @Test func test_explicitChoiceOverridesRollout() {
        #expect(Backend.resolve(preference: .fly, rollout: 1, bucket: 0) == .fly)
        #expect(Backend.resolve(preference: .cloudflare, rollout: 0, bucket: 0.999) == .cloudflare)
        #expect(Backend.resolve(preference: .cloudflare, rollout: 0, bucket: nil) == .cloudflare)
    }

    @Test func test_automaticWithoutUsernameStaysOnFly() {
        #expect(Backend.resolve(preference: .automatic, rollout: 1, bucket: nil) == .fly)
    }

    @Test func test_bucketIsStablePerAccount() {
        // A pure function of the username, so every device on the account agrees.
        let bucket = Backend.rolloutBucket(username: "someone@example.com")
        #expect((0..<1).contains(bucket))
        #expect(Backend.rolloutBucket(username: "someone@example.com") == bucket)
        #expect(Backend.rolloutBucket(username: "  SomeOne@Example.COM\n") == bucket)
        #expect(Backend.rolloutBucket(username: "someone-else@example.com") != bucket)
    }

    @Test func test_bucketMatchesSHA256Prefix() {
        // SHA-256("abc") starts ba7816bf8f01cfea; its top 53 bits over 2^53.
        let expected = Double(UInt64(0xba7816bf8f01cfea) >> 11) / Double(UInt64(1) << 53)
        #expect(Backend.rolloutBucket(username: "ABC") == expected)
    }

    @Test func test_sanitizedRollout() {
        #expect(Backend.sanitizedRollout(nil) == 0)
        #expect(Backend.sanitizedRollout(.nan) == 0)
        #expect(Backend.sanitizedRollout(-0.5) == 0)
        #expect(Backend.sanitizedRollout(0.25) == 0.25)
        #expect(Backend.sanitizedRollout(3) == 1)
    }

}

/// Exercises the persisted values in the shared suite, so it restores them and runs serially.
@Suite(.serialized)
struct BackendPersistenceTests {

    @Test func test_activeBackendDefaultsToFly() {
        let saved = Defaults[.activeBackend]
        defer { Defaults[.activeBackend] = saved }

        Defaults.reset(.activeBackend)
        #expect(Backend.active == .fly)
    }

    @Test func test_wantedUsesPersistedPreference() {
        let saved = (Defaults[.cloudflareRollout], Defaults[.backendPreference])
        defer {
            Defaults[.cloudflareRollout] = saved.0
            Defaults[.backendPreference] = saved.1
        }

        // An explicit choice needs no username, so this holds whoever is signed in.
        Defaults[.cloudflareRollout] = 0
        Defaults[.backendPreference] = .cloudflare
        #expect(Backend.wanted == .cloudflare)
        Defaults[.cloudflareRollout] = 1
        Defaults[.backendPreference] = .fly
        #expect(Backend.wanted == .fly)
    }

}

struct BannersDecodingTests {

    private func decode(_ json: String) throws -> Banners {
        try JSONDecoder().decode(Banners.self, from: Data(json.utf8))
    }

    @Test func test_decodesWithoutRollout() throws {
        let banners = try decode(#"{"banners": [], "minVersion": "2.7.2"}"#)
        #expect(banners.minVersion == "2.7.2")
        #expect(banners.cloudflareRollout == nil)
    }

    @Test func test_decodesRollout() throws {
        #expect(try decode(#"{"banners": [], "cloudflareRollout": 0.25}"#).cloudflareRollout == 0.25)
        #expect(try decode(#"{"banners": [], "cloudflareRollout": 1}"#).cloudflareRollout == 1)
        #expect(try decode(#"{"banners": [], "cloudflareRollout": null}"#).cloudflareRollout == nil)
    }

    @Test func test_invalidRolloutKeepsTheRest() throws {
        let banners = try decode(#"{"banners": [{"id": "a"}], "minVersion": "2.7.2", "cloudflareRollout": "50%"}"#)
        #expect(banners.cloudflareRollout == nil)
        #expect(banners.banners.map(\.id) == ["a"])
        #expect(banners.minVersion == "2.7.2")
    }

}
