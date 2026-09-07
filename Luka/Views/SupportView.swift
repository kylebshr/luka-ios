//
//  SupportView.swift
//  Luka
//
//  Created by Claude on 9/7/26.
//

import StoreKit
import SwiftUI
import TelemetryDeck

/// Where `SupportView` was opened from, for telemetry.
enum SupportSource: String, Identifiable {
    case banner = "Banner"
    case prompt = "Prompt"
    case settings = "Settings"

    var id: String { rawValue }
}

/// Explains why Luka asks for support and offers the monthly supporter tiers.
/// Presented from the promo banner, Settings, and the post-start prompt.
struct SupportView: View {
    @Environment(SupporterStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var source: SupportSource

    @State private var selectedTier: SupporterTier = .supporter
    @State private var isPresentingManageSubscriptions = false

    private var isCurrentTierSelected: Bool {
        store.currentTier == selectedTier
    }

    var body: some View {
        NavigationStack {
            FooterScrollView {
                VStack(alignment: .leading, spacing: .largeVerticalSpacing) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.accent)

                    VStack(alignment: .leading, spacing: .spacing4) {
                        Text(store.isSupporter ? "Thank You!" : "Support Luka")
                            .font(.title.bold())

                        if let currentTier = store.currentTier {
                            Text("\(Text(currentTier.thanks)) It keeps Live Activities running.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Live Activities run on a server I pay for every month. Luka is free with no ads. Supporting unlocks nothing, but it keeps the lights on.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.leading)

                    VStack(spacing: .spacing4) {
                        ForEach(SupporterTier.allCases) { tier in
                            TierRow(
                                tier: tier,
                                displayPrice: store.displayPrice(for: tier),
                                isSelected: tier == selectedTier,
                                isCurrent: tier == store.currentTier
                            ) {
                                selectedTier = tier
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .withReadableWidth()
                .padding()
                .padding(.horizontal)
                .padding(.top, .spacing8)
            } footer: {
                footer
                    .withReadableWidth()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .padding(.horizontal)
            }
            .toolbar {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .fontDesign(.rounded)
        .animation(.default, value: store.currentTier)
        .animation(.snappy, value: selectedTier)
        .onAppear {
            selectedTier = store.currentTier ?? .supporter
            TelemetryDeck.signal("Support.viewed", parameters: ["source": source.rawValue])
        }
        .onChange(of: store.currentTier) {
            if let currentTier = store.currentTier {
                selectedTier = currentTier
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { store.purchaseError != nil },
                set: { if !$0 { store.purchaseError = nil } }
            ),
            actions: {
                Button("OK") {}
            },
            message: {
                Text(store.purchaseError ?? "")
            }
        )
        .manageSubscriptionsSheet(isPresented: $isPresentingManageSubscriptions)
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: .spacing6) {
            if store.isSupporter, isCurrentTierSelected {
                prominentButton("Manage Subscription") {
                    isPresentingManageSubscriptions = true
                }
            } else {
                prominentButton(
                    store.isSupporter
                        ? "Switch to \(Text(selectedTier.name))"
                        : "Support for \(store.displayPrice(for: selectedTier))/mo"
                ) {
                    Task {
                        await store.purchase(selectedTier, source: source.rawValue)
                    }
                }
                .disabled(store.products[selectedTier] == nil || store.isPurchasing)
            }

            if !store.isSupporter {
                Button("Restore Purchases") {
                    Task {
                        await store.restore()
                    }
                }
                .font(.subheadline.weight(.medium))
                .disabled(store.isPurchasing)

                legalText
            }
        }
    }

    private func prominentButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .animation(nil, value: store.isPurchasing)
                .opacity(store.isPurchasing ? 0 : 1)
                .overlay {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    }
                }
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
        .buttonBorderShape(.capsule)
    }

    private var legalText: some View {
        VStack(spacing: .spacing1) {
            Text("Renews monthly. Cancel anytime in Settings.")

            HStack(spacing: .spacing1) {
                Link("Terms of Use", destination: SupporterStore.termsOfUseURL)
                Text("•")
                Link("Privacy Policy", destination: SupporterStore.privacyPolicyURL)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.top, .spacing4)
    }
}

private struct TierRow: View {
    var tier: SupporterTier
    var displayPrice: String
    var isSelected: Bool
    var isCurrent: Bool
    var onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: .spacing6) {
                Image(systemName: tier.systemImage)
                    .font(.title3)
                    .foregroundStyle(.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: .spacing1) {
                    HStack(spacing: .spacing4) {
                        Text(tier.name)
                            .font(.headline)
                            .fixedSize(horizontal: true, vertical: false)

                        if isCurrent {
                            Text("Current")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, .spacing4)
                                .padding(.vertical, .spacing1)
                                .background(.accent.opacity(0.15), in: .capsule)
                                .foregroundStyle(.accent)
                        }
                    }

                    Text(tier.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                .layoutPriority(1)

                Spacer(minLength: .spacing4)

                Text("\(displayPrice)/mo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                Color(.systemGroupedBackground),
                in: .rect(cornerRadius: .defaultCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: .defaultCornerRadius)
                    .strokeBorder(.tint, lineWidth: isSelected ? 2 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SupportView(source: .settings)
        .environment(SupporterStore())
}
