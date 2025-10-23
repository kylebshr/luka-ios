//
//  BackgroundTextFieldStyle.swift
//  Luka
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI

struct CardTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(.fill.quaternary, in: .rect(cornerRadius: 16))
    }
}
