//
//  FormSectionHeader.swift
//  Hako
//
//  Created by Kyle Bashour on 3/6/24.
//

import SwiftUI

struct FormHeader: View {
    var title: LocalizedStringKey

    var body: some View {
        Text(title)
            .foregroundStyle(.secondary)
            .fontWeight(.medium)
            .padding(.leading, .standardPadding)
            .padding(.top, .verticalSpacing)
    }
}
