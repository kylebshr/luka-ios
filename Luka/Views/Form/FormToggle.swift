//
//  FormToggle.swift
//  Hako
//
//  Created by Kyle Bashour on 3/6/24.
//

import SwiftUI
import Defaults

struct FormToggle: View {
    var title: LocalizedStringKey
    var description: LocalizedStringKey?

    @Binding private var isOn: Bool

    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        get: @escaping () -> Bool,
        set: @escaping (Bool) -> Void
    ) {
        self.title = title
        self.description = description
        self._isOn = .init(get: get, set: set)
    }

    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        key: Defaults.Key<Bool>
    ) {
        self.title = title
        self.description = description
        self._isOn = .init(
            get: { Defaults[key] },
            set: { Defaults[key] = $0 }
        )
    }

    var body: some View {
        HStack(alignment: .toggleAlignmentGuide) {
            VStack(alignment: .leading, spacing: .spacing1) {
                Text(title)
                    .alignmentGuide(.toggleAlignmentGuide, computeValue: { dimension in
                        dimension[VerticalAlignment.center]
                    })

                if let description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, .standardPadding / 2)

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
        }
        .fontWeight(.medium)
        .padding(.horizontal, .standardPadding / 2)
    }
}

private extension VerticalAlignment {
    private struct ToggleAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let toggleAlignmentGuide = VerticalAlignment(
        ToggleAlignment.self
    )
}
