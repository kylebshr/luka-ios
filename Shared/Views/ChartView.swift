//
//  ChartView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/29/24.
//

import SwiftUI
import Charts
import Dexcom

struct ChartView: View {
    let range: ClosedRange<Date>
    let readings: [GlucoseReading]
    let maximumY: Int
    let targetRange: ClosedRange<Int>

    var body: some View {
        Chart {
            ForEach(readings) { reading in
                PointMark(
                    x: .value("", reading.date),
                    y: .value(reading.value.formatted(), reading.value)
                )
                .symbol {
                    Circle()
                        .frame(width: 2.5)
                        .foregroundStyle(.foreground)
                }
            }
        }
        .chartXScale(domain: range)
        .chartYScale(domain: 0...maximumY)
        .chartYAxis {
            let values = [55, maximumY]
            AxisMarks(values: values) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
            }
        }
        .chartXAxis {
//            AxisMarks(values: .stride(by: .hour, count: 1)) {
//                AxisGridLine()
//            }
        }
        .chartOverlay { chart in
            GeometryReader { geometry in
                if let plotFrame = chart.plotFrame {
                    let frame = geometry[plotFrame]
                    if let origin = chart.position(for: (range.lowerBound, targetRange.upperBound)), let max = chart.position(for: (range.upperBound, targetRange.lowerBound)) {

                        Rectangle()
                            .fill(.green.quinary)
                            .frame(width: frame.width, height: max.y - origin.y)
                            .position(x: (max.x - origin.x) / 2, y: (max.y - origin.y) / 2 + origin.y)
                    }

                    if let origin = chart.position(for: (range.lowerBound, targetRange.lowerBound)), let max = chart.position(for: (range.upperBound, 0)) {

                        Rectangle()
                            .fill(.red.quinary)
                            .frame(width: frame.width, height: max.y - origin.y)
                            .position(x: (max.x - origin.x) / 2, y: (max.y - origin.y) / 2 + origin.y)
                    }
                }
            }
        }
    }
}

extension GlucoseReading: Identifiable {
    public var id: Self { self }
}

#Preview {
    ChartView(
        range: Date.now.addingTimeInterval(-60 * 60 * 3)...Date.now,
        readings: .placeholder,
        maximumY: 300,
        targetRange: 70...180
    ).frame(height: 200)
}
