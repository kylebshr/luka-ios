//
//  MainView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/26/24.
//

import Defaults
import Dexcom
import SwiftUI
import TelemetryDeck
import WidgetKit

@MainActor struct MainView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Default(.selectedRange) private var portraitRange
    @Default(.selectedLandscapeRange) private var landscapeRange
    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.graphUpperBound) private var upperGraphRange
    @Default(.unit) private var unit
    @Default(.dismissedBannerIDs) private var dismissedBannerIDs
    @Default(.showChartLiveActivity) private var showChartLiveActivity

    @Default(.isLiveActivityRunning) private var isActivityActive

    @State private var isPresentingSettings = false
    @State private var liveViewModel = LiveViewModel()
    @State private var isActivityLoading = false
    @State private var selectedChartReading: LiveActivityState.Reading?
    @State private var haptics = UIImpactFeedbackGenerator(style: .rigid)

    private var selectedRange: Binding<GraphRange> {
        isCompact ? $landscapeRange : $portraitRange
    }

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

    private var isCompact: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        let banners = viewModel.displayableBanners(dismissedBannerIDs: dismissedBannerIDs)

        NavigationStack {
            VStack(alignment: .leading) {
                readingView()
                    .padding([.horizontal, .bottom])

                if !isCompact {
                    ForEach(banners) { banner in
                        BannerView(banner: banner) {
                            dismissedBannerIDs.insert(banner.id)
                            TelemetryDeck.signal("Banner.dismissed", parameters: ["id": banner.id])
                        }
                        .padding(.horizontal)
                    }
                }

                Picker("Graph range", selection: selectedRange) {
                    ForEach(GraphRange.allCases) {
                        Text($0.abbreviatedName)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, isCompact ? 0 : nil)
                .padding(.bottom, .verticalSpacing)

                LineChart(
                    range: selectedRange.wrappedValue,
                    readings: readings.toLiveActivityReadings(),
                    showAxisLabels: true,
                    useFullYRange: true,
                    selectedReading: $selectedChartReading,
                )
                .padding(.trailing)
                .padding(.leading, isCompact ? nil : 0)
                .padding(.bottom)

                if !isCompact {
                    liveActivityButton()
                }
            }
            .padding(.top, isCompact ? nil : 0)
            .edgesIgnoringSafeArea(isCompact ? .top : [])
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
        .onChange(of: scrubbingGlucoseReading) {
            haptics.impactOccurred()
            haptics.prepare()
        }
        .animation(.snappy, value: dismissedBannerIDs)
        .onChange(of: showChartLiveActivity) {
            liveViewModel.updateLiveActivityIfActive()
        }
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

        isActivityLoading = true
        defer { isActivityLoading = false }

        do {
            if isActivityActive {
                _ = try await EndLiveActivityIntent().perform()
            } else {
                _ = try await StartLiveActivityIntent(source: "App").perform()
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Failed to toggle Live Activity: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func readingView() -> some View {
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
        .animation(isScrubbing ? nil : .default, value: displayReading)
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
