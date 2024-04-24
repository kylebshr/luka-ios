//
//  ContentView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import KeychainAccess

struct ContentView: View {
    @State private var username: String = Keychain.shared.username ?? ""
    @State private var password: String = Keychain.shared.password ?? ""

    var body: some View {
        ScrollView {
            VStack {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)

                Button("Save") {
                    Keychain.shared.username = username
                    Keychain.shared.password = password
                }
                .padding()
            }
            .textFieldStyle(.roundedBorder)
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
