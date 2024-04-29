//
//  GlucoseReading+Extensions.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import Dexcom
import SwiftUI

extension GlucoseReading {
    var color: Color {
        switch value {
        case ..<70:
            Color.red
        case ...180:
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
            Image(systemName: "questionmark")
        case .rateOutOfRange:
            Image(systemName: "exclamationmark")
        }
    }

    func timestamp(
        for currentDate: Date,
        style: DateComponentsFormatter.UnitsStyle = .short,
        nowText: String? = nil
    ) -> String {
        if currentDate.timeIntervalSince(date) < 60 {
            if let nowText {
                return nowText
            } else {
                switch style {
                case .abbreviated:
                    return "now"
                default:
                    return "Just now"
                }
            }
        } else {
            let formatter = formatter(style: style)
            let text = formatter.string(from: date, to: currentDate)!

            switch style {
            case .abbreviated:
                return text
            default:
                return text + " ago"
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

extension [GlucoseReading] {
    static var placeholder: [GlucoseReading] {
        (0..<(24*60/5)).map { (value: Int) in
            .init(
                value: Int(sin(Double(value * 1200)) * 60) + 130,
                trend: .flat,
                date: Date.now.addingTimeInterval(Double(-value * 5 * 60))
            )
        }
    }
}
