//
//  LukaWidgetBundle.swift
//  LukaWidget
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import SwiftUI

@main
struct LukaWidgetBundle: WidgetBundle {
    var body: some Widget {
        GraphWidget()
        ReadingWidget()
        #if os(iOS)
        ReadingActivityConfiguration()
        if #available(iOS 18.0, *) {
            LiveActivityControl()
        }
        #endif
    }
}
