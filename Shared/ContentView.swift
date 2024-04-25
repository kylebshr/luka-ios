//
//  ContentView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import KeychainAccess
import WidgetKit

struct ContentView: View {
    @State private var username: String = Keychain.shared.username ?? ""
    @State private var password: String = Keychain.shared.password ?? ""

    @State private var accountID = Keychain.shared.accountID
    @State private var sessionID = Keychain.shared.sessionID

    var body: some View {
        ScrollView {
            VStack {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $password)
                    .textContentType(.password)

                Button("Save") {
                    Keychain.shared.username = username
                    Keychain.shared.password = password
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .padding(.top)

                if let accountID {
                    Text("Account ID")
                    Text(accountID.uuidString)
                }

                if let sessionID {
                    Text("Session ID")
                    Text(sessionID.uuidString)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
