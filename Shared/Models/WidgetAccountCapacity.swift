//
//  WidgetAccountCapacity.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import AppIntents

/// The widgets that can show several accounts.
enum AccountWidgetKind: CaseIterable {
    case reading
    case graph

    /// How many accounts a widget of this kind shows in `family`. The `size:` of
    /// each configuration's `accounts` parameter repeats this table, because the
    /// App Intents metadata processor only accepts a literal there; LukaTests
    /// checks the built metadata against it.
    func capacity(for family: IntentWidgetFamily) -> Int {
        switch (self, family) {
        case (.reading, .systemSmall): 2
        case (.reading, .systemMedium): 2
        case (.reading, .systemLarge): 4
        case (.reading, .accessoryRectangular): 2
        case (.graph, .systemMedium): 2
        case (.graph, .systemLarge): 3
        default: 1
        }
    }
}
