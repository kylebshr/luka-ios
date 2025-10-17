//
//  ReadingActivityConfiguration.swift
//  LukaWidget
//
//  Created by Kyle Bashour on 10/16/25.
//

import WidgetKit
import ActivityKit
import Dexcom
import Foundation
import SwiftUI

struct ReadingActivityConfiguration: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingAttributes.self) { context in
            context.state.history.last?.image
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    context.state.history.last?.image
                }

                DynamicIslandExpandedRegion(.trailing) {
                    context.state.history.last?.image
                }

                DynamicIslandExpandedRegion(.bottom) {
                    context.state.history.last?.image
                }
            } compactLeading: {
                context.state.history.last?.image
            } compactTrailing: {
                context.state.history.last?.image
            } minimal: {
                context.state.history.last?.image
            }
        }
    }
}
