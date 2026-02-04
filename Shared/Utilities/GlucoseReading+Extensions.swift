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
        case ..<target.lowerBound: .lowColor
        case ...target.upperBound: .inRangeColor
        default: .highColor
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

    func isExpired(at atDate: Date, expiration: Measurement<UnitDuration> = .init(value: 25, unit: .minutes)) -> Bool {
        atDate.timeIntervalSince(date) > expiration.converted(to: .seconds).value
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
                return String(localized: "Just now")
            } else {
                return String(localized: "Now")
            }
        } else {
            let formatter = formatter(style: style)
            let text = formatter.string(from: date, to: currentDate)!

            if appendRelativeText {
                return String(localized: "\(text) ago", comment: "Relative time suffix, e.g. '5 min ago'")
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
    static let placeholder = [GlucoseReading].placeholder.last!
    static func placeholder(date: Date) -> GlucoseReading {
        var reading = placeholder
        reading.date = date
        return reading
    }
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
        // Real glucose data from 24 hours of readings
        // Values and trends from actual Dexcom readings
        let realData: [(value: Int, trend: TrendDirection)] = [
            (100, .flat), (104, .flat), (110, .flat), (122, .fortyFiveUp), (129, .fortyFiveUp),
            (131, .flat), (134, .flat), (132, .flat), (134, .flat), (149, .fortyFiveUp),
            (159, .fortyFiveUp), (155, .flat), (149, .flat), (146, .flat), (131, .fortyFiveDown),
            (125, .fortyFiveDown), (118, .fortyFiveDown), (117, .flat), (112, .flat), (109, .flat),
            (110, .flat), (112, .flat), (128, .flat), (140, .fortyFiveUp), (128, .flat),
            (104, .fortyFiveDown), (89, .fortyFiveDown), (79, .fortyFiveDown), (70, .fortyFiveDown), (68, .fortyFiveDown),
            (71, .fortyFiveDown), (88, .flat), (95, .flat), (105, .fortyFiveUp), (103, .flat),
            (106, .flat), (115, .flat), (118, .flat), (118, .flat), (126, .flat),
            (138, .fortyFiveUp), (137, .flat), (130, .flat), (118, .flat), (110, .flat),
            (101, .flat), (101, .flat), (99, .flat), (87, .flat), (74, .fortyFiveDown),
            (79, .flat), (81, .flat), (89, .flat), (86, .flat), (99, .flat),
            (109, .fortyFiveUp), (110, .flat), (124, .fortyFiveUp), (131, .fortyFiveUp), (130, .flat),
            (123, .flat), (117, .flat), (118, .flat), (115, .flat), (111, .flat),
            (116, .flat), (116, .flat), (114, .flat), (114, .flat), (114, .flat),
            (116, .flat), (113, .flat), (106, .flat), (104, .flat), (101, .flat),
            (101, .flat), (105, .flat), (104, .flat), (110, .flat), (116, .flat),
            (124, .flat), (142, .fortyFiveUp), (133, .flat), (137, .flat), (142, .flat),
            (149, .flat), (154, .flat), (152, .flat), (144, .flat), (140, .flat),
            (139, .flat), (139, .flat), (139, .flat), (138, .flat), (138, .flat),
            (140, .flat), (140, .flat), (141, .flat), (139, .flat), (139, .flat),
            (139, .flat), (138, .flat), (143, .flat), (144, .flat), (152, .flat),
            (164, .fortyFiveUp), (170, .fortyFiveUp), (179, .fortyFiveUp), (184, .fortyFiveUp), (181, .flat),
            (193, .flat), (205, .fortyFiveUp), (210, .fortyFiveUp), (220, .fortyFiveUp), (223, .fortyFiveUp),
            (218, .flat), (220, .flat), (243, .fortyFiveUp), (248, .fortyFiveUp), (240, .flat),
            (239, .flat), (237, .flat), (234, .flat), (230, .flat), (236, .flat),
            (234, .flat), (232, .flat), (231, .flat), (224, .flat), (218, .flat),
            (217, .flat), (217, .flat), (193, .fortyFiveDown), (190, .fortyFiveDown), (205, .flat),
            (216, .flat), (215, .flat), (211, .flat), (193, .fortyFiveDown), (185, .fortyFiveDown),
            (181, .flat), (177, .flat), (179, .flat), (169, .flat), (164, .flat),
            (156, .fortyFiveDown), (167, .flat), (185, .flat), (176, .flat), (167, .flat),
            (169, .flat), (171, .flat), (170, .flat), (172, .flat), (179, .flat),
            (184, .flat), (186, .flat), (181, .flat), (176, .flat), (170, .flat),
            (157, .fortyFiveDown), (162, .flat), (162, .flat), (172, .flat), (171, .flat),
            (174, .flat), (174, .flat), (173, .flat), (178, .flat), (168, .flat),
            (165, .flat), (158, .flat), (159, .flat), (172, .flat), (178, .fortyFiveUp),
            (173, .flat), (175, .flat), (157, .flat), (152, .fortyFiveDown), (163, .flat),
            (169, .flat), (151, .flat), (136, .fortyFiveDown), (141, .flat), (144, .flat),
            (145, .flat), (162, .flat), (169, .fortyFiveUp), (165, .flat), (168, .flat),
            (171, .flat), (158, .flat), (156, .flat), (160, .flat), (161, .flat),
            (162, .flat), (162, .flat), (170, .flat), (177, .flat), (168, .flat),
            (173, .flat), (184, .flat), (192, .flat), (192, .flat), (189, .flat),
            (193, .flat), (196, .flat), (198, .flat), (199, .flat), (201, .flat),
            (195, .fortyFiveDown), (189, .fortyFiveDown), (183, .fortyFiveDown), (177, .fortyFiveDown), (171, .fortyFiveDown),
            (165, .fortyFiveDown), (159, .fortyFiveDown), (153, .fortyFiveDown), (147, .fortyFiveDown), (141, .fortyFiveDown),
            (135, .fortyFiveDown), (129, .fortyFiveDown), (123, .fortyFiveDown), (120, .flat), (118, .flat),
            (117, .flat), (119, .flat), (121, .flat), (122, .fortyFiveUp), (126, .flat),
            (131, .flat), (125, .flat), (120, .flat), (117, .flat), (119, .flat),
            (121, .flat), (117, .flat), (114, .flat), (106, .flat), (112, .flat),
            (118, .flat), (112, .flat), (111, .flat), (115, .flat), (113, .flat),
            (112, .flat), (110, .flat), (110, .flat), (101, .flat), (110, .flat),
            (113, .flat), (111, .flat), (110, .flat), (109, .flat), (99, .flat),
            (93, .flat), (94, .flat), (95, .flat), (102, .flat), (100, .flat),
            (94, .flat), (93, .flat), (89, .flat), (86, .flat), (98, .flat),
            (99, .flat), (92, .flat), (92, .flat), (101, .flat), (103, .flat),
            (104, .flat), (104, .flat), (100, .flat), (95, .flat), (95, .flat),
            (84, .flat), (73, .fortyFiveDown), (85, .flat), (92, .flat), (86, .flat),
            (85, .flat), (84, .flat), (84, .flat), (90, .flat), (91, .flat),
            (86, .flat), (87, .flat), (94, .flat), (95, .flat), (95, .flat),
            (101, .flat), (117, .fortyFiveUp), (263, .fortyFiveUp)
        ]

        // Create readings with timestamps relative to now
        // Each reading is 5 minutes apart, working backwards from most recent
        var readings: [GlucoseReading] = []
        for (index, data) in realData.enumerated() {
            let minutesAgo = (realData.count - 1 - index) * 5
            let date = Date.now.addingTimeInterval(Double(-minutesAgo * 60))

            readings.append(GlucoseReading(
                value: data.value,
                trend: data.trend,
                date: date
            ))
        }

        return readings
    }()
}
