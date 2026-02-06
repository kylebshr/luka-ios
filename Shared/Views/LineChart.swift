//
//  LineChart.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import SwiftUI
import Charts
import Dexcom
import Defaults

struct LineChart: View {
    @Default(.targetRangeLowerBound) var lowerBound
    @Default(.targetRangeUpperBound) var upperBound
    @Default(.graphUpperBound) var graphUpperBound
    @Default(.unit) var unit

    var range: GraphRange
    var style: GraphStyle
    var readings: [LiveActivityState.Reading]
    var lineWidth: CGFloat = 2
    var showAxisLabels: Bool = false
    var useFullYRange: Bool = false
    var selectedReading: Binding<LiveActivityState.Reading?>? = nil

    @GestureState private var isScrubbing = false
    @State private var chartWidth: CGFloat = 350

    /// Calculates dot size based on time range and chart width - more points or smaller width means smaller dots
    private var dotSymbolSize: CGFloat {
        // Dexcom provides ~12 readings per hour (every 5 min)
        // Scale inversely with expected point count, clamped to reasonable bounds
        let hours = range.timeInterval / 3600
        let expectedPoints = hours * 12

        // Base size that looks good, scaled by lineWidth for consistency
        var calculatedSize = (lineWidth * 350) / expectedPoints

        // Scale down for smaller chart widths (reference: 350pt typical phone width)
        let widthScale = min(1.0, chartWidth / 350)
        calculatedSize *= widthScale

        return max(lineWidth * 4, min(lineWidth * 30, calculatedSize))
    }

    /// Size for the emphasized current reading dot (symbol size units)
    private var emphasizedDotSymbolSize: CGFloat {
        dotSymbolSize * 4
    }

    private var filteredReadings: [LiveActivityState.Reading] {
        if useFullYRange {
            return readings
        } else {
            // Filter out older readings so we scale the y axis to current readings
            let startDate = switch style {
            case .line:
                // pad a little so it can go off the edge.
                Date.now.addingTimeInterval(-(range.timeInterval + 60 * 15))
            case .dots:
                Date.now.addingTimeInterval(-range.timeInterval)
            }

            return readings.filter { reading in
                reading.t >= startDate
            }
        }
    }

    private var yScaleRange: ClosedRange<Int> {
        if useFullYRange {
            return 0...Int(graphUpperBound)
        }

        let allValues = filteredReadings.map(\.v)
        guard let dataMin = allValues.min(), let dataMax = allValues.max() else {
            return Int(lowerBound)...Int(upperBound)
        }

        let targetRangeHeight = Int(upperBound - lowerBound)
        let dataRangeHeight = Int(dataMax - dataMin)

        // Ensure minimum height equals target range
        if dataRangeHeight < targetRangeHeight {
            let expansion = targetRangeHeight - dataRangeHeight
            let expandBottom = expansion / 2
            let expandTop = expansion - expandBottom
            return (Int(dataMin) - expandBottom)...(Int(dataMax) + expandTop)
        }

        return Int(dataMin)...Int(dataMax)
    }

    private var emphasizedReading: LiveActivityState.Reading? {
        if let selectedReading = selectedReading?.wrappedValue {
            return selectedReading
        } else if let lastReading = filteredReadings.last, Date.now.timeIntervalSince(lastReading.t) < 7 * 60 {
            return lastReading
        } else {
            return nil
        }
    }

    var body: some View {
        Chart {
            ForEach(filteredReadings, id: \.t) { reading in
                let clampedValue = useFullYRange ? min(reading.v, Int16(graphUpperBound)) : reading.v

                switch style {
                case .dots:
                    if reading != emphasizedReading {
                        PointMark(
                            x: .value("Date", reading.t),
                            y: .value("Glucose", clampedValue)
                        )
                        .foregroundStyle(colorForValue(Int(reading.v)))
                        .symbolSize(dotSymbolSize)
                    }
                case .line:
                    LineMark(
                        x: .value("Date", reading.t),
                        y: .value("Glucose", clampedValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            stops: gradientStops,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }

            if let emphasizedReading {
                let clampedValue = useFullYRange ? min(emphasizedReading.v, Int16(graphUpperBound)) : emphasizedReading.v

                if selectedReading?.wrappedValue != nil {
                    RuleMark(x: .value("Date", emphasizedReading.t))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 0.5))
                }

                PointMark(
                    x: .value("Date", emphasizedReading.t),
                    y: .value("Glucose", clampedValue)
                )
                .foregroundStyle(colorForValue(Int(emphasizedReading.v)))
                .symbolSize(emphasizedDotSymbolSize)
                .symbol(DonutSymbolShape(fill: style == .line))
            }
        }
        .chartYScale(domain: yScaleRange)
        .chartXScale(domain: Date.now.addingTimeInterval(-range.timeInterval)...Date.now)
        .chartXAxis {
            if showAxisLabels {
                if range.timeInterval > 60 * 60 * 2 {
                    AxisMarks(
                        format: .dateTime.hour(),
                        preset: .aligned,
                        values: .automatic(desiredCount: 4)
                    )
                } else {
                    let endDate = Date.now
                    let startDate = endDate - range.timeInterval
                    AxisMarks(
                        format: .dateTime.hour().minute(),
                        preset: .aligned,
                        values: Array(stride(from: endDate, to: startDate, by: -range.timeInterval / 4))
                    )
                }
            }
        }
        .chartYAxis {
            if showAxisLabels {
                let rangeMarks = [Int(lowerBound), Int(upperBound)].filter {
                    yScaleRange.contains($0)
                }

                AxisMarks(values: rangeMarks) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    AxisValueLabel(
                        format: GlucoseFormatter(unit: unit),
                        collisionResolution: .greedy(priority: 50)
                    )
                }

                let boundaryMarks = [yScaleRange.lowerBound, yScaleRange.upperBound]
                AxisMarks(values: boundaryMarks) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    AxisValueLabel(
                        format: GlucoseFormatter(unit: unit),
                        collisionResolution: .greedy(priority: 50)
                    )
                }

                if yScaleRange.contains(55) {
                    AxisMarks(values: [55]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                            .foregroundStyle(Color.lowColor.secondary)
                        AxisValueLabel(
                            format: GlucoseFormatter(unit: unit),
                            collisionResolution: .greedy(priority: 100)
                        )
                    }
                }
            }
        }
        .animation(.smooth.speed(1.5), value: range)
        .chartOverlay { proxy in
            if let selectedReading {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($isScrubbing) { value, state, transaction in
                                    state = true

                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let frame = geometry[plotFrame]

                                    // Clamp the x position to the frame bounds instead of returning nil
                                    let rawXPosition = value.location.x - frame.origin.x
                                    let xPosition = max(0, min(rawXPosition, frame.width))

                                    if let date: Date = proxy.value(atX: xPosition, as: Date.self) {
                                        selectedReading.wrappedValue = readingClosest(to: date)
                                    }
                                }
                        )
                }
                .onChange(of: isScrubbing) { oldValue, newValue in
                    if !newValue {
                        selectedReading.wrappedValue = nil
                    }
                }
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear {
                    chartWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    chartWidth = newWidth
                }
            }
        }
    }

    private var gradientStops: [Gradient.Stop] {
        // Use actual data range for gradient, not extended yScaleRange
        let allValues = filteredReadings.map(\.v)
        guard let dataMin = allValues.min(), let dataMax = allValues.max() else {
            return [Gradient.Stop(color: .inRangeColor, location: 0)]
        }

        let dataRange = Double(dataMax - dataMin)
        guard dataRange > 0 else {
            // All values are the same, pick appropriate color
            let value = Int(dataMin)
            let color = colorForValue(value)
            return [Gradient.Stop(color: color, location: 0)]
        }

        let lowerBoundLocation = (Double(lowerBound) - Double(dataMin)) / dataRange
        let upperBoundLocation = (Double(upperBound) - Double(dataMin)) / dataRange

        var stops: [Gradient.Stop] = []

        // Determine color at bottom (location 0)
        let bottomColor: Color = lowerBoundLocation > 0 ? .lowColor : (upperBoundLocation > 0 ? .inRangeColor : .highColor)
        stops.append(Gradient.Stop(color: bottomColor, location: 0))

        // Sharp transition to in-range (no blending between colors)
        if lowerBoundLocation > 0 && lowerBoundLocation < 1 {
            stops.append(Gradient.Stop(color: .lowColor, location: max(0, lowerBoundLocation - 0.05)))
            stops.append(Gradient.Stop(color: .inRangeColor, location: min(1, lowerBoundLocation + 0.05)))
        }

        // Sharp transition to high (no blending between colors)
        if upperBoundLocation > 0 && upperBoundLocation < 1 {
            stops.append(Gradient.Stop(color: .inRangeColor, location: max(0, upperBoundLocation - 0.05)))
            stops.append(Gradient.Stop(color: .highColor, location: min(1, upperBoundLocation + 0.05)))
        }

        // Determine color at top (location 1)
        let topColor: Color = upperBoundLocation < 1 ? .highColor : (lowerBoundLocation < 1 ? .inRangeColor : .lowColor)
        stops.append(Gradient.Stop(color: topColor, location: 1))

        return stops.sorted { $0.location < $1.location }
    }

    private func colorForValue(_ value: Int) -> Color {
        if value < Int(lowerBound) {
            return .lowColor
        } else if value > Int(upperBound) {
            return .highColor
        } else {
            return .inRangeColor
        }
    }

    private func readingClosest(to date: Date) -> LiveActivityState.Reading? {
        guard !filteredReadings.isEmpty else { return nil }
        return filteredReadings.min { lhs, rhs in
            abs(lhs.t.timeIntervalSince(date)) < abs(rhs.t.timeIntervalSince(date))
        }
    }
}

#Preview {
    VStack {
        LineChart(
            range: .eightHours,
            style: .line,
            readings: .placeholder,
            showAxisLabels: true,
        )
        .frame(height: 70)
        .padding(1)
        .border(.blue.opacity(0.5))
        .padding()

        LineChart(
            range: .threeHours,
            style: .dots,
            readings: .placeholder,
            showAxisLabels: true,
            useFullYRange: false,
        )
        .frame(height: 100)
        .padding(1)
        .border(.blue.opacity(0.5))
        .padding()

        LineChart(
            range: .eightHours,
            style: .dots,
            readings: .placeholder,
            showAxisLabels: true,
            useFullYRange: false,
        )
        .frame(height: 100)
        .padding(1)
        .border(.blue.opacity(0.5))
        .padding()

        LineChart(
            range: .twentyFourHours,
            style: .dots,
            readings: .placeholder,
            showAxisLabels: true,
            useFullYRange: true,
        )
        .frame(height: 400)
        .padding(1)
        .border(.blue.opacity(0.5))
        .padding()

        Spacer()
    }
}
