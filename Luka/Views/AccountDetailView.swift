//
//  AccountDetailView.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Defaults
import Dexcom
import SwiftUI

/// One account's large reading, range picker and scrubbable chart. It's the
/// whole main screen with a single account, and the pushed detail of an
/// account card with several. The root passes its banners and Live Activity
/// controls in through `banners` and `footer`.
struct AccountDetailView<Banners: View, Footer: View>: View {
    var liveViewModel: LiveViewModel
    /// Set when pushed from the account list; nil at the root.
    var title: String?
    @ViewBuilder var banners: Banners
    @ViewBuilder var footer: Footer

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Default(.selectedRange) private var portraitRange
    @Default(.selectedLandscapeRange) private var landscapeRange
    @Default(.appGraphStyle) private var graphStyle

    @State private var selectedChartReading: LiveActivityState.Reading?
    @State private var haptics = UIImpactFeedbackGenerator(style: .rigid)

    private var isCompact: Bool {
        verticalSizeClass == .compact
    }

    private var isRoot: Bool {
        title == nil
    }

    private var selectedRange: Binding<GraphRange> {
        isCompact ? $landscapeRange : $portraitRange
    }

    private var readings: [GlucoseReading] {
        liveViewModel.readings
    }

    private var scrubbingGlucoseReading: GlucoseReading? {
        guard let selectedChartReading else { return nil }
        return readings.first { $0.date == selectedChartReading.t }
    }

    private var displayReading: GlucoseReading? {
        scrubbingGlucoseReading ?? readings.last
    }

    private var isScrubbing: Bool {
        scrubbingGlucoseReading != nil
    }

    private var subtitleText: String {
        if let scrubbingGlucoseReading {
            scrubbingGlucoseReading.date.formatted(date: .omitted, time: .shortened)
        } else {
            liveViewModel.message
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ReadingSummaryView(
                reading: displayReading,
                delta: displayReading.flatMap { readings.delta(at: $0) },
                subtitle: subtitleText,
                isRedacted: !isScrubbing && liveViewModel.isStale,
                animatesChanges: !isScrubbing
            )
            .padding([.horizontal, .bottom])

            if !isCompact {
                banners
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
                style: graphStyle,
                readings: readings.toLiveActivityReadings(),
                showAxisLabels: true,
                yRangeMode: .full,
                selectedReading: $selectedChartReading,
            )
            .padding(.trailing)
            .padding(.leading, isCompact ? nil : 0)
            .padding(.bottom)

            if !isCompact {
                footer
            }
        }
        // At the root in landscape the reading slides up beside the toolbar
        // buttons; a pushed detail keeps clear of its back button and title.
        .padding(.top, isCompact && isRoot ? nil : 0)
        .edgesIgnoringSafeArea(isCompact && isRoot ? .top : [])
        .modifier { view in
            if let title {
                view
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                view
            }
        }
        .onAppear {
            haptics.prepare()
        }
        .onChange(of: scrubbingGlucoseReading) {
            haptics.impactOccurred()
            haptics.prepare()
        }
    }
}

#if DEBUG
#Preview("Pushed") {
    @Previewable @State var model = PreviewAccounts.liveViewModel(name: "Mom")
    let _ = PreviewAccounts.showLiveActivities(for: [])

    NavigationStack {
        AccountDetailView(liveViewModel: model, title: "Mom") {
            EmptyView()
        } footer: {
            LiveActivityButton(account: model.account)
        }
        .fontDesign(.rounded)
    }
}

#Preview("Pushed, Live Activity running") {
    @Previewable @State var model = PreviewAccounts.liveViewModel(name: "Mom")
    let _ = PreviewAccounts.showLiveActivities(for: [model.account])

    NavigationStack {
        AccountDetailView(liveViewModel: model, title: "Mom") {
            EmptyView()
        } footer: {
            LiveActivityButton(account: model.account)
        }
        .fontDesign(.rounded)
    }
}
#endif
