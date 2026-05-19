//
//  LiveActivityControl.swift
//  Luka
//
//  Created by Claude on 1/2/26.
//

import Defaults
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct LiveActivityControl: ControlWidget {
    static let kind = "com.kylebashour.Glimpse.LiveActivityControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { value in
            ControlWidgetToggle(
                "Live Activity",
                isOn: value,
                action: ToggleLiveActivityIntent()
            ) { isOn in
                Label(isOn ? "On" : "Off", systemImage: "arrow.right")
            }
            .tint(.green)
        }
        .displayName("Live Activity")
        .description("Toggle your glucose Live Activity.")
    }
}

@available(iOS 18.0, *)
extension LiveActivityControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            Defaults[.isLiveActivityRunning]
        }
    }
}
