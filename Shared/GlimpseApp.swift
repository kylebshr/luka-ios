//
//  GlimpseApp.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import WidgetKit

@main
struct GlimpseApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
