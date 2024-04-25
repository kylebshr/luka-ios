//
//  CircularWidgetErrorView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct CircularWidgetErrorView: View {
    let imageName: String

    var body: some View {
        ZStack {
            Circle().fill(.fill.secondary)
            Image(systemName: imageName)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .containerBackground(.fill, for: .widget)
    }
}
