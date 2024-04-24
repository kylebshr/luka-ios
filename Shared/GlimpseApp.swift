//
//  GlimpseApp.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI

@main
struct GlimpseApp: App {
    private let cloudDefaults = CloudDefaults()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { cloudDefaults.initialize() }
        }
    }
}
