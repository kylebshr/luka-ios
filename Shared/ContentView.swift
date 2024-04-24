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

    var body: some View {
        ScrollView {
            VStack {
                TextField("Username", text: $username)
                TextField("Password", text: $password)

                Button("Save") {
                    UserDefaults.shared.username = username
                    UserDefaults.shared.password = password
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .padding()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
