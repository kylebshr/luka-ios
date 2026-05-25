//
//  SettingsRow.swift
//  Luka
//
//  Created by Claude on 5/25/26.
//

import SwiftUI

struct SettingsRow: View {
    @ScaledMetric private var iconFrameWidth: CGFloat = 24

    var title: LocalizedStringKey
    var systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: systemImage)
                .frame(width: iconFrameWidth, alignment: .center)
        }
    }
}
