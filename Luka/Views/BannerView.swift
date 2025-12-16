//
//  BannerView.swift
//  Luka
//
//  Created by Kyle Bashour on 12/14/25.
//

import SwiftUI

struct BannerView: View {
    var banner: Banner
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                if let title = banner.title {
                    Text(title)
                        .font(.headline)
                }

                if let body = banner.body {
                    Text(body)
                        .font(.body)
                }
            }

            Spacer()

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.headline)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            Color(.systemGroupedBackground),
            in: .rect(cornerRadius: .defaultCornerRadius)
        )
    }
}

#Preview {
    BannerView(
        banner: .init(
            id: "foo",
            title: "Have a Banner",
            body: "Have some body, blah blah blah. Blah blah blah blah blah."
        ),
        onDismiss: {}
    )
    .padding()
}
