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
            intent: StartLiveActivityIntent(source: "Shortcut"),
            phrases: [
                "Monitor glucose levels with \(.applicationName)",
                "\(.applicationName) live activity",
            ],
            shortTitle: "Start Live Activity",
            systemImageName: "arrow.right"
        )

        AppShortcut(
            intent: EndLiveActivityIntent(),
            phrases: [
                "Stop \(.applicationName) live activity",
                "End \(.applicationName) live activity",
            ],
            shortTitle: "End Live Activity",
            systemImageName: "stop.fill"
        )
    }
}
