//
//  SettingsView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/28/24.
//

import SwiftUI
import Defaults
import Dexcom

struct SettingsView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.graphUpperBound) private var upperGraphRange
    @Default(.unit) private var unit

    var body: some View {
        FooterScrollView {
            VStack(alignment: .leading, spacing: .verticalSpacing) {
                Spacer()

                FormSection {
                    FormRow(title: "Units") {
                        Menu {
                            Picker("Units", selection: $unit) {
                                Text(GlucoseFormatter.Unit.mgdl.text)
                                    .tag(GlucoseFormatter.Unit.mgdl)
                                Text(GlucoseFormatter.Unit.mmolL.text)
                                    .tag(GlucoseFormatter.Unit.mmolL)
                            }
                        } label: {
                            Text(unit.text).fontWeight(.medium)
                        }
                    }
                }

                FormHeader(title: "Graphs")

                FormSection {
                    GraphSliderView(
                        title: "Upper bound",
                        currentValue: $upperGraphRange,
                        range: 220...400
                    )

                    FormSectionDivider()

                    GraphSliderView(
                        title: "Upper target range",
                        currentValue: $upperTargetRange,
                        range: 120...220
                    )

                    FormSectionDivider()

                    GraphSliderView(
                        title: "Lower target range",
                        currentValue: $lowerTargetRange,
                        range: 55...110
                    )
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
        .fontDesign(.rounded)
    }
}

private struct GraphSliderView: View {
    var title: String
    @Binding var currentValue: Double
    var range: ClosedRange<Double>

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
