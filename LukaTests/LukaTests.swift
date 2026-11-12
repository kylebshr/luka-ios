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

    @Test func test_bucketIsGeneratedOnceAndPersisted() {
        let saved = Defaults[.backendRolloutBucket]
        defer { Defaults[.backendRolloutBucket] = saved }

        Defaults[.backendRolloutBucket] = nil
        let bucket = Backend.rolloutBucket
        #expect((0..<1).contains(bucket))
        #expect(Defaults[.backendRolloutBucket] == bucket)
        #expect(Backend.rolloutBucket == bucket)
    }

    @Test func test_currentUsesPersistedValues() {
        let saved = (Defaults[.backendRolloutBucket], Defaults[.cloudflareRollout], Defaults[.backendPreference])
        defer {
            Defaults[.backendRolloutBucket] = saved.0
            Defaults[.cloudflareRollout] = saved.1
            Defaults[.backendPreference] = saved.2
        }

        Defaults[.backendRolloutBucket] = 0.3
        Defaults[.backendPreference] = .automatic
        Defaults[.cloudflareRollout] = 0.5
        #expect(Backend.current == .cloudflare)
        Defaults[.cloudflareRollout] = 0.2
        #expect(Backend.current == .fly)
        Defaults[.backendPreference] = .cloudflare
        #expect(Backend.current == .cloudflare)
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

struct LiveActivityBackendsTests {

    @Test func test_newActivityUsesCurrentAndSticks() {
        var backends = LiveActivityBackends()
        #expect(backends.register("a", current: .cloudflare) == .cloudflare)
        #expect(backends.register("a", current: .fly) == .cloudflare)
        #expect(backends.backend(for: "a", current: .fly) == .cloudflare)
    }

    @Test func test_knownActivityKeepsItsBackend() {
        var backends = LiveActivityBackends(byActivityID: ["old": .fly])
        #expect(backends.register("old", current: .cloudflare) == .fly)
        #expect(backends.register("new", current: .cloudflare) == .cloudflare)
    }

    @Test func test_unregisteredActivityUsesCurrentWithoutRemembering() {
        let backends = LiveActivityBackends()
        #expect(backends.backend(for: "a", current: .cloudflare) == .cloudflare)
        #expect(backends.byActivityID.isEmpty)
    }

    @Test func test_endAllReachesBothBackends() {
        #expect(LiveActivityBackends().allBackends(current: .fly) == [.fly, .cloudflare])
        #expect(LiveActivityBackends().allBackends(current: .cloudflare) == [.fly, .cloudflare])
        #expect(LiveActivityBackends(byActivityID: ["a": .local]).allBackends(current: .fly) == [.fly, .cloudflare, .local])
    }

    @Test func test_pruneForgetsEndedActivities() {
        var backends = LiveActivityBackends(byActivityID: ["running": .fly, "ended": .cloudflare])
        #expect(backends.prune(keeping: ["running"]) == ["ended": .cloudflare])
        #expect(backends.byActivityID == ["running": .fly])

        backends.forget("running")
        #expect(backends.byActivityID.isEmpty)
    }

    @Test func test_roundTripsThroughStorage() throws {
        let backends = LiveActivityBackends(byActivityID: ["a": .fly, "b": .cloudflare])
        let decoded = try JSONDecoder().decode(LiveActivityBackends.self, from: JSONEncoder().encode(backends))
        #expect(decoded == backends)
    }

}
