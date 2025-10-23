//
//  View+Modifier.swift
//  Luka
//
//  Created by Kyle Bashour on 10/23/25.
//

import SwiftUI

extension View {
    func modifier(@ViewBuilder _ modifier: (Self) -> some View) -> some View {
        modifier(self)
    }
}
