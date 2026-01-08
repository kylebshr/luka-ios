//
//  Color+Extensions.swift
//  Luka
//
//  Created by Kyle Bashour on 10/20/25.
//

import SwiftUI

extension Color {
    static var lowColor: Color {
        if #available(iOS 26, *), #available(watchOS 11, *) {
            Color.pink.mix(with: .red, by: 0.5)
        } else {
            Color.red
        }
    }
    static var inRangeColor: Color {
        if #available(iOS 26, *), #available(watchOS 11, *) {
            Color.mint.mix(with: .green, by: 0.5)
        } else {
            Color.green
        }
    }
    static var highColor: Color {
        if #available(iOS 26, *), #available(watchOS 11, *) {
            Color.yellow.mix(with: .orange, by: 0.5)
        } else {
            Color.yellow
        }
    }
}
