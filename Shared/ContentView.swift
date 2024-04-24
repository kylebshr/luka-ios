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
    @State private var username: String = UserDefaults.shared.username ?? ""
    @State private var password: String = UserDefaults.shared.password ?? ""

    @State private var accountID = UserDefaults.shared.accountID
    @State private var sessionID = UserDefaults.shared.sessionID

    var body: some View {
        ScrollView {
            VStack {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $password)
                    .textContentType(.password)

                Button("Save") {
                    UserDefaults.shared.username = username
                    UserDefaults.shared.password = password
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
