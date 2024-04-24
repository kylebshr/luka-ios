//
//  AppIntent.swift
//  WatchWidget
//
//  Created by Kyle Bashour on 4/23/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Dexcom Settings"
    static var description = IntentDescription("Configure Dexcom widget settings.")

    @Parameter(title: "Outside US", default: false)
    var outsideUS: Bool
}
