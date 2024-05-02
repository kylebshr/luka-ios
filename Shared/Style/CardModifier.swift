//
//  CardModifier.swift
//  Hako
//
//  Created by Kyle Bashour on 3/4/24.
//

import SwiftUI

extension View {
    func card(padding: EdgeInsets = .init(.standardPadding)) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct CardModifier: ViewModifier {
    var padding: EdgeInsets

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: .defaultCornerRadius)
                    .fill(.background.secondary)
                    .strokeBorder(.quinary, lineWidth: 1)
            }
    }
}
