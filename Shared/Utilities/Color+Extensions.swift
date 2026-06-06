//
//  Color+Extensions.swift
//  Luka
//
//  Created by Kyle Bashour on 10/20/25.
//

import SwiftUI

extension Color {
    // On iOS/watchOS 26+ the colors are nudged into HDR headroom via
    // `exposureAdjust` so out-of-range readings glow on capable displays.
    // In-range gets a much gentler lift so it stays calm; everything falls
    // back to the plain SDR color on older OSes and non-HDR displays.
    static var lowColor: Color {
        if #available(iOS 26, *), #available(watchOS 26, *) {
            Color.pink.mix(with: .red, by: 0.7).exposureAdjust(0.5)
        } else if #available(iOS 26, *), #available(watchOS 11, *) {
            Color.pink.mix(with: .red, by: 0.7)
        } else {
            Color.red
        }
    }
    static var inRangeColor: Color {
        if #available(iOS 26, *), #available(watchOS 26, *) {
            Color.green.mix(with: .mint, by: 0.25).exposureAdjust(0.2)
        } else if #available(iOS 26, *), #available(watchOS 11, *) {
            Color.green.mix(with: .mint, by: 0.25)
        } else {
            Color.green
        }
    }
    static var highColor: Color {
        if #available(iOS 26, *), #available(watchOS 26, *) {
            Color.yellow.mix(with: .orange, by: 0.65).exposureAdjust(0.5)
        } else if #available(iOS 26, *), #available(watchOS 11, *) {
            Color.yellow.mix(with: .orange, by: 0.65)
        } else {
            Color.orange
        }
    }
}
