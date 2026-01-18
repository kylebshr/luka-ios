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
