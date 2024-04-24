//
//  ContentView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import KeychainAccess

struct ContentView: View {
    @State private var username: String = Keychain.standard[.usernameKey] ?? ""
    @State private var password: String = Keychain.standard[.passwordKey] ?? ""

    var body: some View {
        ScrollView {
            VStack {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)

                Button("Save") {
                    Keychain.standard[.usernameKey] = username
                    Keychain.standard[.passwordKey] = password
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
