//
//  LukaTests.swift
//  LukaTests
//
//  Created by Kyle Bashour on 1/17/26.
//

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
