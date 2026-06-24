//
//  View+Extensions.swift
//  Luka
//
//  Created by Kyle Bashour on 4/30/24.
//

import SwiftUI

extension View {
    var watchOS: Bool {
        #if os(watchOS)
        return true
        #else
        return false
        #endif
    }

    /// Applies lowercase small caps to the current font. Glucose readings
    /// outside the sensor's measurable range format as "Low"/"Hi", and small
    /// caps renders those words at a height that sits well alongside the
    /// numeric readings.
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
