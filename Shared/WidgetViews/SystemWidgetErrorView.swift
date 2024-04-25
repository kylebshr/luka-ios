//
//  SystemWidgetErrorView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import WidgetKit

struct SystemWidgetErrorView: View {
    let imageName: String

    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: imageName)
                .unredacted()

            Spacer()

            Button(intent: ReloadWidgetIntent()) {
                HStack {
                    Text("Reload")

                    Spacer()

                    Image(systemName: "arrow.circlepath")
                        .unredacted()
                }
                .font(.footnote)
                .fontWeight(.medium)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
