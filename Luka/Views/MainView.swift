//
//  MainView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/26/24.
//

import ActivityKit
import Defaults
import Dexcom
import SwiftUI
import WidgetKit

@MainActor struct MainView: View {
    @Environment(RootViewModel.self) private var viewModel

    @Default(.selectedRange) private var selectedRange
    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.graphUpperBound) private var upperGraphRange
    @Default(.unit) private var unit

    @State private var isPresentingSettings = false
    @State private var liveViewModel = LiveViewModel()
    @State private var activity: Activity<ReadingAttributes>? = Activity.activities
        .compactMap { $0 as? Activity<ReadingAttributes> }
        .first

    private var readings: [GlucoseReading] {
        switch liveViewModel.state {
        case .loaded(let readings, _):
            return readings
        default:
            return []
        }
    }

    private var readingText: String {
        switch liveViewModel.state {
        case .initial, .noRecentReading, .error:
            return "100"
        case .loaded(_, let latest):
            return latest.value.formatted(.glucose(unit))
        }
    }

    private var isRedacted: Bool {
        switch liveViewModel.state {
        case .initial:
            return true
        case .loaded(_, let latest):
            return latest.isExpired(at: .now)
        case .noRecentReading:
            return true
        case .error:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .center) {
                VStack(alignment: .center, spacing: 0) {
                    Text(liveViewModel.message)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: liveViewModel.messageValue))
                        .animation(.default, value: liveViewModel.message)

                    Spacer().frame(height: 10)

                    HStack(spacing: 5) {
                        Text(readingText)
                            .contentTransition(.numericText(value: Double(readings.last?.value ?? 0)))
                            .redacted(reason: isRedacted ? .placeholder : [])

                        readings.last?.image
                            .imageScale(.small)
                            .contentTransition(.symbolEffect(.replace))
                            .transition(.blurReplace)
                    }
                    .font(.largeTitle.weight(.medium))
                    .animation(.default, value: readingText)

                    Text(unit.text)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .redacted(reason: isRedacted ? .placeholder : [])
                }
                .padding()

                GraphView(
                    range: selectedRange,
                    readings: readings,
                    highlight: readings.last,
                    graphUpperBound: Int(upperGraphRange),
                    targetRange: Int(lowerTargetRange)...Int(upperTargetRange),
                    roundBottomCorners: false,
                    showMarkLabels: true
                )
                .edgesIgnoringSafeArea(.leading)
                .padding(.trailing)
                
                Picker("Graph range", selection: $selectedRange) {
                    ForEach(GraphRange.allCases) {
                        Text($0.abbreviatedName)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Live Activity", systemImage: "bolt.fill") {
                        startLiveActivity()
                    }
                    .tint(activity == nil ? nil : .blue)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Settings", systemImage: "person.fill") {
                        isPresentingSettings = true
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear {
            liveViewModel.setUpClientAndBeginRefreshing()
            observeActivityUpdates()
        }
        .fontDesign(.rounded)
        .onChange(of: readings, initial: true) { _, newValue in
            Task {
                await activity?.update(using: .init(history: newValue.suffix(36)))
            }
        }
    }

    private func startLiveActivity() {
        guard activity == nil else {
            return
        }

        if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                let attributes = ReadingAttributes()
                let initialState = ReadingAttributes.ContentState(history: Array(readings.suffix(36)))

                activity = try Activity.request(
                    attributes: attributes,
                    content: .init(
                        state: initialState,
                        staleDate: .now.addingTimeInterval(61 * 2)
                    ),
                    pushType: .token
                )

                observeActivityUpdates()
            } catch {
                print("Couldn't start activity \(String(describing: error))")
            }
        }
    }

    private func observeActivityUpdates() {
        guard let activity else { return }

        Task {
            for await token in activity.pushTokenUpdates {
                let token = token.map { String(format: "%02x", $0) }.joined()
                print(token)
            }
        }

        Task {
            for await state in activity.activityStateUpdates {
                print(state)
            }
        }

    }
}

#Preview {
    NavigationStack {
        MainView().environment(RootViewModel())
    }
}
