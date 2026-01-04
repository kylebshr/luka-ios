//
//  FormRow.swift
//  Hako
//
//  Created by Kyle Bashour on 3/21/24.
//

import SwiftUI

struct FormRow<Accessory: View>: View {
    var title: LocalizedStringKey
    var description: LocalizedStringKey?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: .spacing1) {
                Text(title)

                if let description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            accessory
        }
        .padding(.standardPadding / 2)
        .multilineTextAlignment(.leading)
        .fontWeight(.medium)
        .contentShape(.rect)
    }
}

extension FormRow where Accessory == EmptyView {
    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil
    ) {
        self.init(title: title, description: description) {
            EmptyView()
        }
    }
}
