//
//  BannerView.swift
//  Luka
//
//  Created by Kyle Bashour on 12/14/25.
//

import SwiftUI

struct BannerView: View {
    var banner: Banner

    var body: some View {
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
        )
    )
    .padding()
}
