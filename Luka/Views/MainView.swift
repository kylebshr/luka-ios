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
    @State private var activity: Activity<ReadingAttributes>? = Activity<ReadingAttributes>.activities
        .first
    @State private var isActivityLoading = false

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

    private var isActivityActive: Bool {
        guard let activity else { return false }
        return activity.activityState == .active
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 0) {
                    ReadingView(reading: readings.last)
                        .font(.largeTitle.weight(.semibold))
                        .animation(.default, value: readings.last)

                    let unit = isRedacted ? "" : "\(unit.text) • "

                    VStack {
                        Text("\(unit)\(liveViewModel.message)")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: liveViewModel.messageValue))
                    .animation(.default, value: liveViewModel.message)
                    .textCase(.uppercase)
                }
                .padding([.horizontal, .bottom])

                Picker("Graph range", selection: $selectedRange) {
                    ForEach(GraphRange.allCases) {
                        Text($0.abbreviatedName)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .padding(.bottom, 20)

                LineChart(
                    range: selectedRange,
                    readings: readings.toLiveActivityReadings(),
                    showAxisLabels: true,
                    useFullYRange: true
                )
                .edgesIgnoringSafeArea(.leading)
                .padding([.trailing, .bottom])

                Button {
                    Task {
                        await toggleLiveActivity()
                    }
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text(isActivityActive ? "Stop Live Activity" : "Start Live Activity")
                    }
                    .animation(nil, value: isActivityLoading)
                    .opacity(isActivityLoading ? 0 : 1)
                    .overlay {
                        if isActivityLoading {
                            ProgressView().tint(.primary)
                        }
                    }
                    .foregroundStyle(isActivityActive ? .white : Color(.label))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .modifier {
                    if #available(iOS 26, *) {
                        $0.buttonStyle(.glassProminent)
                    } else {
                        $0.buttonStyle(.borderedProminent)
                    }
                }
                .tint(isActivityActive ? .blue : .clear)
                .padding()
            }
            .toolbar {
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
        }
        .fontDesign(.rounded)
        .task {
            for await activity in Activity<ReadingAttributes>.activityUpdates {
                self.activity = activity
            }
        }
    }

    private func toggleLiveActivity() async {
        guard !isActivityLoading else { return }

        if isActivityActive {
            // End the active Live Activity
            await activity?.end(nil, dismissalPolicy: .immediate)
            activity = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            isActivityLoading = true
            defer { isActivityLoading = false }

            // Start a new Live Activity using the Intent
            let intent = StartLiveActivityIntent()
            do {
                _ = try await intent.perform()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                print("Failed to start Live Activity: \(error)")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MainView().environment(RootViewModel())
    }
}
