//
//  CircleSymbol.swift
//  Luka
//
//  Created by Kyle Bashour on 1/8/26.
//

import Charts
import SwiftUI

struct DonutSymbolShape: ChartSymbolShape {
    let perceptualUnitRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    let fill: Bool

    func path(in rect: CGRect) -> Path {
        if fill {
            return Path(ellipseIn: rect)
        }

        let lineWidth = rect.width * 0.25
        let insetRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        return Path(ellipseIn: insetRect).strokedPath(StrokeStyle(lineWidth: lineWidth))
    }
}
