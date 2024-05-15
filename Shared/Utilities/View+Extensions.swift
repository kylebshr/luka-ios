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
}
