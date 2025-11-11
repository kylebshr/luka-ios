//
//  FormSection.swift
//  Hako
//
//  Created by Kyle Bashour on 3/6/24.
//

import SwiftUI

struct FormSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: .standardPadding / 2) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: .init(.standardPadding / 2))
    }
}
