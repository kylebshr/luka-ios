//
//  LukaApp.swift
//  Luka
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import WidgetKit

@main
struct LukaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = RootViewModel()

    var body: some Scene {
        WindowGroup {
            RootView().environment(viewModel)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
