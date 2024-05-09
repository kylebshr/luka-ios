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
    let showMarkLabels: Bool

    private var adjustedRange: ClosedRange<Date> {
        range.lowerBound...range.upperBound.addingTimeInterval(5 * 60)
    }

    private var interval: TimeInterval {
        range.upperBound.timeIntervalSinceReferenceDate - range.lowerBound.timeIntervalSinceReferenceDate
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width * geometry.size.height
            let range = interval / 50
            let size: CGFloat = scale * 0.015 * (1 / range)
            let markSize = max(min(size, 5.5), 2.5)

            Chart {
                ForEach(readings) { reading in
                    let value = min(reading.value, graphUpperBound)
                    PointMark(
                        x: .value("", reading.date),
                        y: .value(value.formatted(), value)
                    )
                    .symbol {
                        if reading.hashValue == highlight?.hashValue {
                            Circle()
                                .fill(.background)
                                .stroke(.foreground, lineWidth: 1.5)
                                .frame(width: markSize * 1.4)
                                .animation(.default, value: markSize)
                        } else {
                            Circle()
                                .frame(width: markSize)
                                .foregroundStyle(.foreground)
                                .animation(.default, value: markSize)
                        }
                    }
                }
            }
            .overlay {
                VStack {
                    Text(scale.formatted())
                    Text(markSize.formatted())
                    Text(range.formatted())
                }
            }
            .foregroundStyle(.foreground)
            .chartXScale(domain: adjustedRange)
            .chartYScale(domain: 0...graphUpperBound)
            .chartYAxis {
                let standardMarks = showMarkLabels ? [0, targetRange.lowerBound, targetRange.upperBound, graphUpperBound] : [graphUpperBound]

                AxisMarks(values: standardMarks) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))

                    if showMarkLabels {
                        AxisValueLabel(collisionResolution: .greedy(priority: 50))
                    }
                }

                AxisMarks(values: [55]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                        .foregroundStyle(.foreground.secondary)

                    if showMarkLabels {
                        AxisValueLabel(collisionResolution: .greedy(priority: 100))
                    }
                }
            }
            .chartXAxis {
                if showMarkLabels {
                    AxisMarks {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour(), anchor: .topTrailing)
                    }
                }
            }
            .chartBackground { graph in
                GeometryReader { geometry in
                    if let plotFrame = graph.plotFrame {
                        let frame = geometry[plotFrame]
                        if let origin = graph.position(for: (adjustedRange.lowerBound, targetRange.upperBound)), let max = graph.position(for: (adjustedRange.upperBound, targetRange.lowerBound)) {

                            Rectangle()
                                .fill(.green.opacity(0.25))
                                .frame(width: frame.width, height: max.y - origin.y)
                                .position(x: (max.x - origin.x) / 2, y: (max.y - origin.y) / 2 + origin.y)
                        }

                        if let origin = graph.position(for: (adjustedRange.lowerBound, targetRange.lowerBound)), let max = graph.position(for: (adjustedRange.upperBound, 0)) {
                            Rectangle()
                                .fill(.pink.opacity(0.18))
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
        }
        .animation(.default, value: adjustedRange)
    }
}

extension GlucoseReading: Identifiable {
    public var id: Self { self }
}

#Preview {
    VStack {
        GraphView(
            range: Date.now.addingTimeInterval(-60 * 60 * 1)...Date.now,
            readings: .placeholder,
            highlight: [GlucoseReading].placeholder.last,
            graphUpperBound: 300,
            targetRange: 70...180,
            roundBottomCorners: false,
            showMarkLabels: false
        ).frame(width: 150, height: 60)

        GraphView(
            range: Date.now.addingTimeInterval(-60 * 60 * 6)...Date.now,
            readings: .placeholder,
            highlight: [GlucoseReading].placeholder.last,
            graphUpperBound: 200,
            targetRange: 70...180,
            roundBottomCorners: false,
            showMarkLabels: false
        ).frame(height: 300)

        GraphView(
            range: Date.now.addingTimeInterval(-60 * 60 * 24)...Date.now,
            readings: .placeholder,
            highlight: [GlucoseReading].placeholder.last,
            graphUpperBound: 300,
            targetRange: 70...180,
            roundBottomCorners: false,
            showMarkLabels: false
        ).frame(width: 150, height: 60)

        GraphView(
            range: Date.now.addingTimeInterval(-60 * 60 * 24)...Date.now,
            readings: .placeholder,
            highlight: [GlucoseReading].placeholder.last,
            graphUpperBound: 200,
            targetRange: 70...180,
            roundBottomCorners: false,
            showMarkLabels: false
        ).frame(height: 300)
    }
}
