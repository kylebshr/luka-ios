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

/// The signed-in root. With one account it's that account's detail; with
/// several it's a list of account cards that push to their details. Banners,
/// the Live Activity button and settings live here either way.
@MainActor struct MainView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(SupporterStore.self) private var supporterStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Default(.dismissedBannerIDs) private var dismissedBannerIDs
    @Default(.supportBannerDismissed) private var supportBannerDismissed
    @Default(.liveActivityStartCount) private var liveActivityStartCount
    @Default(.lastSupportPromptDate) private var lastSupportPromptDate

    @Default(.isLiveActivityRunning) private var isActivityActive

    @State private var isPresentingSettings = false
    @State private var supportSheetSource: SupportSource?
    @State private var isActivityLoading = false
    @State private var liveViewModels = LiveViewModelCache()
    @State private var path: [DexcomAccount.ID] = []

    private var isCompact: Bool {
        verticalSizeClass == .compact
    }

    private var accounts: [DexcomAccount] {
        viewModel.accounts
    }

    private var isShowingList: Bool {
        accounts.count > 1
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                if !isShowingList, let account = accounts.first {
                    AccountDetailView(liveViewModel: liveViewModel(for: account), title: nil) {
                        bannerViews
                            .padding(.horizontal)
                    } footer: {
                        liveActivityButton()
                        supportBanner()
                    }
                    .transition(.blurReplace)
                } else {
                    accountList
                        .transition(.blurReplace)
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
            .navigationDestination(for: DexcomAccount.ID.self) { id in
                if let account = accounts.first(where: { $0.id == id }) {
                    AccountDetailView(
                        liveViewModel: liveViewModel(for: account),
                        title: viewModel.displayName(for: account)
                    )
                }
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(item: $supportSheetSource) { source in
            SupportView(source: source)
        }
        .onChange(of: accounts, initial: true) {
            liveViewModels.retain(only: accounts)
            let ids = Set(accounts.map(\.id))
            if !isShowingList || path.contains(where: { !ids.contains($0) }) {
                path = path.filter { ids.contains($0) && isShowingList }
            }
        }
        .fontDesign(.rounded)
        .animation(.snappy, value: isShowingList)
        .animation(.snappy, value: dismissedBannerIDs)
        .animation(.snappy, value: showsSupportBanner)
    }

    private func liveViewModel(for account: DexcomAccount) -> LiveViewModel {
        liveViewModels.model(for: account, store: viewModel.store)
    }

    // MARK: - Account list

    private var accountList: some View {
        ScrollView {
            VStack(spacing: .spacing8) {
                if !isCompact {
                    bannerViews
                        .withReadableWidth()
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320), spacing: .spacing8)],
                    spacing: .spacing8
                ) {
                    ForEach(accounts) { account in
                        NavigationLink(value: account.id) {
                            AccountCard(
                                name: viewModel.displayName(for: account),
                                liveViewModel: liveViewModel(for: account)
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: 1000)

                if !isCompact, showsSupportBanner {
                    supportBannerView
                        .withReadableWidth()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.top, .spacing8)
            .padding(.bottom)
            .animation(.snappy, value: accounts)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isCompact {
                liveActivityButton()
            }
        }
    }

    // MARK: - Banners

    @ViewBuilder private var bannerViews: some View {
        ForEach(viewModel.displayableBanners(dismissedBannerIDs: dismissedBannerIDs)) { banner in
            BannerView(banner: banner) {
                dismissedBannerIDs.insert(banner.id)
                TelemetryDeck.signal("Banner.dismissed", parameters: ["id": banner.id])
            }
        }
    }

    private var showsSupportBanner: Bool {
        !supporterStore.isSupporter && !supportBannerDismissed
    }

    @ViewBuilder private func supportBanner() -> some View {
        if showsSupportBanner {
            supportBannerView
                .withReadableWidth()
                .frame(maxWidth: .infinity)
                .padding([.horizontal, .bottom])
        }
    }

    private var supportBannerView: some View {
        SupportBannerView(displayPrice: supporterStore.lowestDisplayPrice) {
            supportSheetSource = .banner
        } onDismiss: {
            supportBannerDismissed = true
            TelemetryDeck.signal("Support.bannerDismissed")
        }
    }

    /// After the second (and later) start, ask for support. Re-asks at most once
    /// a month, and never once the user subscribes.
    private func showSupportPromptIfNeeded() {
        guard SupportPrompt.shouldShow(
            startCount: liveActivityStartCount,
            isSupporter: supporterStore.isSupporter,
            lastPromptDate: lastSupportPromptDate
        ) else {
            return
        }

        lastSupportPromptDate = .now
        supportSheetSource = .prompt
        TelemetryDeck.signal("Support.promptShown", parameters: ["startCount": String(liveActivityStartCount)])
    }

    // MARK: - Live Activity

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
            let didStart = !isActivityActive
            if isActivityActive {
                _ = try await EndLiveActivityIntent().perform()
            } else {
                _ = try await StartLiveActivityIntent(source: "App").perform()
            }
            LiveActivityManager.shared.syncState()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if didStart {
                showSupportPromptIfNeeded()
            }
        } catch {
            print("Failed to toggle Live Activity: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
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

/// One `LiveViewModel` per account, kept alive across the list, the pushed
/// detail and the switch between one and several accounts, so none of them
/// refetches when the layout changes.
@MainActor private final class LiveViewModelCache {
    private var models: [DexcomAccount.ID: LiveViewModel] = [:]

    func model(for account: DexcomAccount, store: AccountStore) -> LiveViewModel {
        if let model = models[account.id] {
            return model
        }
        let model = LiveViewModel(account: account, store: store)
        #if DEBUG
        if let readings = PreviewAccounts.readings[account.id] {
            model.showPreviewReadings(readings)
        } else {
            model.setUpClientAndBeginRefreshing()
        }
        #else
        model.setUpClientAndBeginRefreshing()
        #endif
        models[account.id] = model
        return model
    }

    func retain(only accounts: [DexcomAccount]) {
        let ids = Set(accounts.map(\.id))
        for (id, model) in models where !ids.contains(id) {
            model.stopRefreshing()
            models[id] = nil
        }
    }
}

#if DEBUG
#Preview("One account") {
    MainView()
        .environment(PreviewAccounts.rootViewModel(names: ["Mom"]))
        .environment(SupporterStore())
}

#Preview("Two accounts") {
    MainView()
        .environment(PreviewAccounts.rootViewModel(names: ["Mom", "Alex"]))
        .environment(SupporterStore())
}

#Preview("Three accounts") {
    MainView()
        .environment(PreviewAccounts.rootViewModel(names: ["Mom", "Alex", "Grandpa"]))
        .environment(SupporterStore())
}
#endif
