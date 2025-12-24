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
import TelemetryDeck
import WidgetKit

@MainActor struct MainView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Default(.selectedRange) private var selectedRange
    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.graphUpperBound) private var upperGraphRange
    @Default(.unit) private var unit
    @Default(.dismissedBannerIDs) private var dismissedBannerIDs

    @State private var isPresentingSettings = false
    @State private var liveViewModel = LiveViewModel()
    @State private var activity: Activity<ReadingAttributes>? = Activity<ReadingAttributes>.activities
        .first
    @State private var isActivityLoading = false
    @State private var selectedChartReading: LiveActivityState.Reading?
    @State private var haptics = UIImpactFeedbackGenerator(style: .rigid)

    private var readings: [GlucoseReading] {
        switch liveViewModel.state {
        case .loaded(let readings, _):
            return readings
        default:
            return []
        }
    }

    private var scrubbingGlucoseReading: GlucoseReading? {
        guard let selectedChartReading else { return nil }
        return readings.first { $0.date == selectedChartReading.t }
    }

    private var displayReading: GlucoseReading? {
        scrubbingGlucoseReading ?? readings.last
    }

    private var subtitleText: String {
        if let scrubbingGlucoseReading {
            scrubbingGlucoseReading.date.formatted(date: .omitted, time: .shortened)
        } else {
            liveViewModel.message
        }
    }

    private var isScrubbing: Bool {
        scrubbingGlucoseReading != nil
    }

    private var isRedacted: Bool {
        if isScrubbing {
            return false
        }

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

    private var isCompact: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        let banners = viewModel.displayableBanners(dismissedBannerIDs: dismissedBannerIDs)

        NavigationStack {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 0) {
                    ReadingView(reading: displayReading)
                        .font(.largeTitle.weight(.semibold))
                        .id(displayReading != nil)

                    let unit = isRedacted ? "" : "\(unit.text) • "

                    Text("\(unit)\(subtitleText)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .padding([.horizontal, .bottom])
                .animation(isScrubbing ? nil : .default, value: displayReading)

                if !isCompact {
                    ForEach(banners) { banner in
                        BannerView(banner: banner) {
                            dismissedBannerIDs.insert(banner.id)
                            TelemetryDeck.signal("Banner.dismissed", parameters: ["id": banner.id])
                        }
                        .padding(.horizontal)
                    }

                    Picker("Graph range", selection: $selectedRange) {
                        ForEach(GraphRange.allCases) {
                            Text($0.abbreviatedName)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .padding(.bottom, 20)
                }

                LineChart(
                    range: selectedRange,
                    readings: readings.toLiveActivityReadings(),
                    showAxisLabels: true,
                    useFullYRange: true,
                    selectedReading: $selectedChartReading,
                )
                .padding(.trailing)
                .padding(.bottom)

                if !isCompact {
                    liveActivityButton()
                }
            }
            .toolbar {
                if #available(iOS 26, *), isCompact {
                    ToolbarItem(placement: .primaryAction) {
                        Button(
                            "Toggle Live Activity",
                            systemImage: "bolt.fill",
                            role: isActivityActive ? .confirm : nil
                        ) {
                            Task {
                                await toggleLiveActivity()
                            }
                        }
                    }
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
            haptics.prepare()
        }
        .fontDesign(.rounded)
        .task {
            for await activity in Activity<ReadingAttributes>.activityUpdates {
                self.activity = activity
            }
        }
        .onChange(of: scrubbingGlucoseReading) {
            haptics.impactOccurred()
            haptics.prepare()
        }
        .onChange(of: scenePhase) {
            activity = Activity<ReadingAttributes>.activities
                .first
        }
        .animation(.snappy, value: dismissedBannerIDs)
    }

    private func liveActivityButton() -> some View {
        return Button {
            Task {
                await toggleLiveActivity()
            }
        } label: {
            HStack {
                ZStack {
                    Image(systemName: "stop.fill").opacity(isActivityActive ? 1 : 0)
                    Image(systemName: "bolt.fill").opacity(isActivityActive ? 0 : 1)
                }
                Text(isActivityActive ? "End Live Activity" : "Start Live Activity")
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
        .tint(isActivityActive ? .accent : inactiveTintColor)
        .withReadableWidth()
        .padding()
        .frame(maxWidth: .infinity)
        .buttonBorderShape(.capsule)
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
            let intent = StartLiveActivityIntent(source: "App")
            do {
                _ = try await intent.perform()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                print("Failed to start Live Activity: \(error)")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private var inactiveTintColor: Color {
        if #available(iOS 26, *) {
            .clear
        } else {
            Color(.systemGroupedBackground)
        }
    }
}

#Preview {
    NavigationStack {
        MainView().environment(RootViewModel())
    }
}
