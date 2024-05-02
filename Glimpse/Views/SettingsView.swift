//
//  SettingsView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/28/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var lowerTargetRange = Double(UserDefaults.shared.targetRangeLowerBound)
    @State private var upperTargetRange = Double(UserDefaults.shared.targetRangeUpperBound)
    @State private var upperChartRange = Double(UserDefaults.shared.chartUpperBound)

    var body: some View {
        FooterScrollView {
            VStack(alignment: .leading, spacing: .verticalSpacing) {
                FormHeader(title: "Chart")

                FormSection {
                    ChartSliderView(
                        title: "Upper bound",
                        currentValue: $upperChartRange,
                        range: 220...400
                    ) {
                        UserDefaults.shared.chartUpperBound = $0
                    }

                    FormSectionDivider()

                    ChartSliderView(
                        title: "Upper target range",
                        currentValue: $upperTargetRange,
                        range: 120...220
                    ) {
                        UserDefaults.shared.targetRangeUpperBound = $0
                    }

                    FormSectionDivider()

                    ChartSliderView(
                        title: "Lower target range",
                        currentValue: $lowerTargetRange,
                        range: 55...110
                    ) {
                        UserDefaults.shared.targetRangeLowerBound = $0
                    }
                }

                Text("Version \(Bundle.main.fullVersion)")
                    .font(.footnote.weight(.medium))
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .largeVerticalSpacing)
                    .multilineTextAlignment(.center)
            }
            .padding([.horizontal, .bottom])
        } footer: {
            Button {
                viewModel.signOut()
            } label: {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding()
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct ChartSliderView: View {
    var title: String
    @Binding var currentValue: Double
    var range: ClosedRange<Double>
    var update: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(currentValue.formatted())
            }
            .fontWeight(.medium)

            Slider(
                value: $currentValue,
                in: range,
                step: 1,
                label: {
                    Text(title)
                },
                onEditingChanged: { bool in
                    update(Int(currentValue))
                }
            )
        }
        .padding(.standardPadding / 2)
    }
}

#Preview {
    NavigationStack {
        SettingsView().environment(RootViewModel())
    }
}
