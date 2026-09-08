//
//  SupportBannerView.swift
//  Luka
//
//  Created by Claude on 9/7/26.
//

import SwiftUI

/// Promo shown under the Live Activity button asking non-supporters to help
/// pay for the server. Tapping opens `SupportView`; the X hides it for good.
struct SupportBannerView: View {
    var displayPrice: String
    var onTap: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .top, spacing: .spacing6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.accent)
                    .font(.headline)
                    .padding(.top, .spacing1)

                VStack(alignment: .leading, spacing: .spacing1) {
                    Text("Support Luka")
                        .font(.headline)

                    Text("Live Activities run on a server that costs money. Chip in from \(displayPrice)/mo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .insetCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SupportBannerView(displayPrice: "99¢", onTap: {}, onDismiss: {})
        .padding()
}
