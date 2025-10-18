//
//  ShortcutProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import AppIntents

extension LukaApp: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .lime

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartLiveActivityIntent(),
            phrases: ["Monitor my glucose levels with \(.applicationName)"],
            shortTitle: "Start Live Activity",
            systemImageName: "bolt.fill"
        )
    }
}
