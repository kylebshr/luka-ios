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
    let readings: [GlucoseChartMark]
    let highlight: GlucoseChartMark?
    let chartUpperBound: Int
    let targetRange: ClosedRange<Int>
    let roundBottomCorners: Bool

    private var adjustedRange: ClosedRange<Date> {
        range.lowerBound...range.upperBound.addingTimeInterval(5 * 60)
    }

    var body: some View {
        Chart {
            ForEach(readings) { reading in
                if adjustedRange.contains(reading.date) {
                    let value = min(reading.value, chartUpperBound)
                    PointMark(
                        x: .value("", reading.date),
                        y: .value(value.formatted(), value)
                    )
                    .symbol {
                        if reading.hashValue == highlight?.hashValue {
                            Circle()
                                .fill(.background)
                                .stroke(.foreground, lineWidth: 1)
                                .frame(width: 3.5, height: 3.5)
                        } else {
                            Circle()
                                .frame(width: 2.5)
                                .foregroundStyle(.foreground)
                        }
                    }
                }
            }
        }
        .foregroundStyle(.foreground)
        .chartXScale(domain: adjustedRange)
        .chartYScale(domain: 0...chartUpperBound)
        .chartYAxis {
            AxisMarks(values: [chartUpperBound]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
            }

            AxisMarks(values: [55]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    .foregroundStyle(.foreground.secondary)
            }
        }
        .chartXAxis {}
        .chartBackground { chart in
            GeometryReader { geometry in
                if let plotFrame = chart.plotFrame {
                    let frame = geometry[plotFrame]
                    if let origin = chart.position(for: (adjustedRange.lowerBound, targetRange.upperBound)), let max = chart.position(for: (adjustedRange.upperBound, targetRange.lowerBound)) {

                        Rectangle()
                            .fill(.green.tertiary)
                            .frame(width: frame.width, height: max.y - origin.y)
                            .position(x: (max.x - origin.x) / 2, y: (max.y - origin.y) / 2 + origin.y)
                    }

                    if let origin = chart.position(for: (adjustedRange.lowerBound, targetRange.lowerBound)), let max = chart.position(for: (adjustedRange.upperBound, 0)) {
                        let height = max.y - origin.y
                        let adjustedHeight = roundBottomCorners ? height / 2 : height

                        Rectangle()
                            .fill(.red.quaternary)
                            .frame(width: frame.width, height: adjustedHeight)
                            .position(x: (max.x - origin.x) / 2, y: adjustedHeight / 2 + origin.y)

                        if roundBottomCorners {
                            ContainerRelativeShape()
                                .fill(.red.quinary)
                                .frame(width: frame.width, height: height)
                                .position(x: (max.x - origin.x) / 2, y: adjustedHeight / 2 + origin.y)
                                .mask(alignment: .bottom) {
                                    Rectangle().frame(width: frame.width, height: adjustedHeight)
                                }
                        }
                    }
                }
            }
        }
        .animation(.default, value: adjustedRange)
    }
}

extension GlucoseReading: Identifiable {
    public var id: Self { self }
}

#Preview {
    ChartView(
        range: Date.now.addingTimeInterval(-60 * 60 * 3)...Date.now,
        readings: .placeholder,
        highlight: [GlucoseChartMark].placeholder.last,
        chartUpperBound: 300,
        targetRange: 70...180,
        roundBottomCorners: false
    ).frame(height: 200)
}
