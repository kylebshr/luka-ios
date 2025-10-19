//
//  GlucoseReading+Extensions.swift
//  Luka
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
        trend: .fortyFiveUp,
        date: [GlucoseReading].placeholder.last!.date
    )
}

extension [LiveActivityState.Reading] {
    static let placeholder = [GlucoseReading].placeholder.toLiveActivityReadings()
}

extension [GlucoseReading] {
    func toLiveActivityReadings() -> [LiveActivityState.Reading] {
        map { .init(t: $0.date, v: Int16($0.value)) }
    }
}

extension [GlucoseReading] {
    static let placeholder: [GlucoseReading] = {
        // Generate 24 hours of data (readings every 5 minutes)
        let readingsCount = 24 * 60 / 5
        var readings: [GlucoseReading] = []

        for i in 0..<readingsCount {
            let minutesAgo = i * 5
            let hoursAgo = Double(minutesAgo) / 60.0
            let date = Date.now.addingTimeInterval(Double(-minutesAgo * 60))

            // Base glucose level around 100-120
            var value = 110.0

            // Add daily rhythm (lower at night, higher during day)
            let hourOfDay = (24.0 - hoursAgo).truncatingRemainder(dividingBy: 24.0)
            value += sin((hourOfDay - 6) * .pi / 12) * 20  // Peak at noon, lowest at midnight

            // Simulate meal spikes (breakfast ~8am, lunch ~12pm, dinner ~6pm)
            if (hourOfDay > 7.5 && hourOfDay < 9.5) {    // Breakfast
                let mealProgress = sin((hourOfDay - 7.5) * .pi)
                value += mealProgress * 80  // Bigger spike for breakfast
            } else if (hourOfDay > 11.5 && hourOfDay < 13.5) {  // Lunch
                let mealProgress = sin((hourOfDay - 11.5) * .pi)
                value += mealProgress * 100  // Large spike for lunch
            } else if (hourOfDay > 17.5 && hourOfDay < 19.5) {   // Dinner
                let mealProgress = sin((hourOfDay - 17.5) * .pi)
                value += mealProgress * 90  // Large spike for dinner
            }

            // Simulate hypoglycemic episodes (low blood sugar)
            if (hourOfDay > 2 && hourOfDay < 3) ||    // Early morning low
               (hourOfDay > 15 && hourOfDay < 16) {   // Afternoon low
                let lowProgress = sin((hourOfDay - 2) * .pi)
                value -= abs(lowProgress) * 50  // Drop to 60-70 range
            }

            // Add more aggressive random variation
            value += Double.random(in: -3...3)

            // Allow wider range (40-280) for more realistic extremes
            value = Swift.max(40, Swift.min(280, value))

            // Determine trend based on previous value
            let prevValue = readings.last?.value ?? Int(value)
            let diff = Int(value) - prevValue
            let trend: TrendDirection = if i > 0 && i < readingsCount - 1 {
                switch diff {
                case ..<(-10): TrendDirection.singleDown
                case -10..<(-2): .fortyFiveDown
                case -2...2: .flat
                case 3...10: .fortyFiveUp
                case 11...: .singleUp
                default: .flat
                }
            } else {
                .flat
            }

            readings.append(GlucoseReading(
                value: Int(value),
                trend: trend,
                date: date
            ))
        }

        return readings.reversed()
    }()
}
