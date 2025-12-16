//
//  ForceUpgradeView.swift
//  Luka
//
//  Created by Kyle Bashour on 12/16/25.
//

import SwiftUI

struct ForceUpgradeView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: .largeVerticalSpacing) {
            Spacer()

            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 64))
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: .spacing4) {
                Text("Update Required")
                    .font(.title.bold())

                Text("This version of Luka is no longer supported. Please update to continue.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)

            Spacer()
            Spacer()

            Button {
                if let url = URL(string: "itms-apps://itunes.apple.com/app/id6499279663") {
                    openURL(url)
                }
            } label: {
                Text("Update Now")
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
        .padding()
        .withReadableWidth()
        .fontDesign(.rounded)
    }
}

#Preview {
    ForceUpgradeView()
}
