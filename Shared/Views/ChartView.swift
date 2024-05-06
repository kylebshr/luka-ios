//
//  GraphView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/29/24.
//

import SwiftUI
import Charts
import Dexcom

struct GraphView: View {
    let range: ClosedRange<Date>
    let readings: [GlucoseReading]
    let highlight: GlucoseReading?
    let graphUpperBound: Int
    let targetRange: ClosedRange<Int>
    let roundBottomCorners: Bool

    private var adjustedRange: ClosedRange<Date> {
        range.lowerBound...range.upperBound.addingTimeInterval(5 * 60)
    }

    var body: some View {
        Chart {
            ForEach(readings) { reading in
                if adjustedRange.contains(reading.date) {
                    let value = min(reading.value, graphUpperBound)
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
        .chartYScale(domain: 0...graphUpperBound)
        .chartYAxis {
            AxisMarks(values: [graphUpperBound]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
            }

            AxisMarks(values: [55]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    .foregroundStyle(.foreground.secondary)
            }
        }
        .chartXAxis {}
        .chartBackground { graph in
            GeometryReader { geometry in
                if let plotFrame = graph.plotFrame {
                    let frame = geometry[plotFrame]
                    if let origin = graph.position(for: (adjustedRange.lowerBound, targetRange.upperBound)), let max = graph.position(for: (adjustedRange.upperBound, targetRange.lowerBound)) {

                        Rectangle()
                            .fill(.green.tertiary)
                            .frame(width: frame.width, height: max.y - origin.y)
                            .position(x: (max.x - origin.x) / 2, y: (max.y - origin.y) / 2 + origin.y)
                    }

                    if let origin = graph.position(for: (adjustedRange.lowerBound, targetRange.lowerBound)), let max = graph.position(for: (adjustedRange.upperBound, 0)) {
                        Rectangle()
                            .fill(.red.quaternary)
                            .frame(width: frame.width, height: max.y - origin.y)
                            .position(x: (max.x - origin.x) / 2, y: (max.y - origin.y) / 2 + origin.y)
                    }
                }
            }
            .clipShape(
                roundBottomCorners 
                ? AnyShape(ContainerRelativeShape())
                : AnyShape(Rectangle())
            )
        }
        .animation(.default, value: adjustedRange)
    }
}

extension GlucoseReading: Identifiable {
    public var id: Self { self }
}

#Preview {
    GraphView(
        range: Date.now.addingTimeInterval(-60 * 60 * 3)...Date.now,
        readings: .placeholder,
        highlight: [GlucoseReading].placeholder.last,
        graphUpperBound: 300,
        targetRange: 70...180,
        roundBottomCorners: false
    ).frame(height: 200)
}
