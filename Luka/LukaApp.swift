//
//  LukaApp.swift
//  Luka
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import WidgetKit
import TelemetryDeck
import Defaults
import StoreKit

@main
struct LukaApp: App {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    @State private var viewModel = RootViewModel()

    init() {
        let config = TelemetryDeck.Config(appID: "7C1E8E40-73DE-4BC4-BDBF-705218647D91")
        TelemetryDeck.initialize(config: config)

        Defaults[.sessionHistory] = []

        #if DEBUG
        Defaults[.dismissedBannerIDs] = []
        #endif

        // Increment launch count
        Defaults[.launchCount] += 1
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(viewModel)
                .onOpenURL(perform: { url in
                    openURL(url)
                })
                .task {
                    // Request review after 10 launches
                    if Defaults[.launchCount] == 10 {
                        requestReview()
                    }
                }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
