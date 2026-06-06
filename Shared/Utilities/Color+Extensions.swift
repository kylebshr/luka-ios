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
            Color.pink.mix(with: .red, by: 0.7)
        } else {
            Color.red
        }
    }
    static var inRangeColor: Color {
        if #available(iOS 26, *), #available(watchOS 11, *) {
            Color.green.mix(with: .mint, by: 0.25)
        } else {
            Color.green
        }
    }
    static var highColor: Color {
        if #available(iOS 26, *), #available(watchOS 11, *) {
            Color.yellow.mix(with: .orange, by: 0.65)
        } else {
            Color.orange
        }
    }
}
