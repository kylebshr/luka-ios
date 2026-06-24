//
//  View+Modifiers.swift
//  Luka
//
//  Created by Kyle Bashour on 11/6/25.
//

import SwiftUI

extension View {
    func withReadableWidth() -> some View {
        frame(maxWidth: 500)
    }

    /// Applies lowercase small caps to the current font. Used wherever a
    /// glucose reading is shown so the out-of-range strings the formatter
    /// returns ("Low" / "Hi") render in small caps alongside numeric values.
    func lowercaseSmallCaps() -> some View {
        modifier(LowercaseSmallCapsModifier())
    }
}

private struct LowercaseSmallCapsModifier: ViewModifier {
    @Environment(\.font) private var font

    func body(content: Content) -> some View {
        content.font((font ?? .body).lowercaseSmallCaps())
    }
}
