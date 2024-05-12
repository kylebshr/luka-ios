//
//  GlucoseReading+Extensions.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import Dexcom
import SwiftUI

extension GlucoseReading {
    func color(target: ClosedRange<Double>) -> Color {
        switch Double(value) {
        case ..<target.lowerBound:
            Color.pink
        case ...target.upperBound:
            Color.green
        default:
            Color.yellow
        }
    }

    var image: Image? {
        switch trend {
        case .none:
            nil
        case .doubleUp:
            Image("arrow.up.double")
        case .singleUp:
            Image(systemName: "arrow.up")
        case .fortyFiveUp:
            Image(systemName: "arrow.up.right")
        case .flat:
            Image(systemName: "arrow.right")
        case .fortyFiveDown:
            Image(systemName: "arrow.down.right")
        case .singleDown:
            Image(systemName: "arrow.down")
        case .doubleDown:
            Image("arrow.down.double")
        case .notComputable:
            nil
        case .rateOutOfRange:
            nil
        }
    }

    func isExpired(at atDate: Date) -> Bool {
        atDate.timeIntervalSince(date) > 20 * 60
    }

    func timestamp(
        for currentDate: Date,
        style: DateComponentsFormatter.UnitsStyle = .short,
        appendRelativeText: Bool = true,
        nowText: String? = nil
    ) -> String {
        if currentDate.timeIntervalSince(date) < 60 {
            if let nowText {
                return nowText
            } else if appendRelativeText {
                return "Just now"
            } else {
                return "Now"
            }
        } else {
            let formatter = formatter(style: style)
            let text = formatter.string(from: date, to: currentDate)!

            if appendRelativeText {
                return text + " ago"
            } else {
                return text
            }
        }
    }

    private func formatter(style: DateComponentsFormatter.UnitsStyle) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = style
        formatter.maximumUnitCount = 1
        return formatter
    }
}

extension GlucoseReading {
    static let placeholder = GlucoseReading(
        value: [GlucoseReading].placeholder.last!.value,
        trend: .flat,
        date: [GlucoseReading].placeholder.last!.date
    )
}

extension [GlucoseReading] {
    static let placeholder: [GlucoseReading] = {
        (0..<(24*60/5)).map { (value: Int) in
            GlucoseReading(
                value: Int(sin(Double(value * 1200)) * 60) + 100,
                trend: .flat,
                date: Date.now.addingTimeInterval(Double(-value * 5 * 60))
            )
        }.reversed()
    }()
}
