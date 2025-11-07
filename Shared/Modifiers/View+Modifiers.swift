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
}
