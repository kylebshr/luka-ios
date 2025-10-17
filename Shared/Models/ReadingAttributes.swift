//
//  ReadingAttributes.swift
//  LukaWidget
//
//  Created by Kyle Bashour on 10/16/25.
//

import ActivityKit
import Foundation
import Dexcom

struct ReadingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var history: [GlucoseReading]
    }
}
