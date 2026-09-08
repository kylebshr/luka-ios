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
            .modifier { view in
                let shape = RoundedRectangle(cornerRadius: .defaultCornerRadius)
                if #available(iOS 26, *), #available(watchOS 26, *) {
                    view.glassEffect(.regular.interactive(), in: shape)
                } else {
                    view.background {
                        shape
                            .fill(.background.secondary)
                            .strokeBorder(.quinary, lineWidth: 1)
                    }
                }
            }
    }
}

extension View {
    /// A flat, subtly tinted card for content that sits inside a screen rather
    /// than floating over it (banners, option rows). Uses the secondary
    /// background so it stays distinct from the screen in both light and dark
    /// mode, including elevated contexts like sheets.
    func insetCard() -> some View {
        background(.background.secondary, in: .rect(cornerRadius: .defaultCornerRadius))
    }
}
