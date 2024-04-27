//
//  ContentView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import KeychainAccess
import WidgetKit

struct SignInView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var outsideUS = false

    @State private var error: Error?
    @State private var isSigningIn = false

    @Environment(RootViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    #endif

                SecureField("Password", text: $password)
                    .textContentType(.password)

                VStack(alignment: .leading) {
                    Toggle("Outside US", isOn: $outsideUS)

                    Divider().padding(.vertical, 10)

                    Text("Sign in using your Dexcom username and password. Dexcom share must be enabled with at least one follower, and Glimpse only works with Dexcom accounts that have an email user ID.\n\nGlimpse is not owned by or affiliated with Dexcom. Your username and password are stored securely in iCloud Keychain.")
                        .font(.footnote)
                        .padding(.top, 5)
                }
                .padding(.top)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task<Void, Never> {
                    isSigningIn = true

                    do {
                        try await viewModel.signIn(
                            username: username,
                            password: password,
                            outsideUS: outsideUS
                        )

                        WidgetCenter.shared.reloadAllTimelines()
                    } catch {
                        self.error = error
                    }

                    isSigningIn = false
                }
            } label: {
                ZStack {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .fontWeight(.semibold)
                        .opacity(isSigningIn ? 0 : 1)

                    ProgressView()
                        .tint(.white)
                        .opacity(isSigningIn ? 1 : 0)
                }
                .animation(.default, value: isSigningIn)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding()
            #if os(iOS)
            .background(Material.bar)
            .overlay(alignment: .top) {
                Divider()
            }
            #endif
        }
        #if os(iOS)
        .textFieldStyle(CardTextFieldStyle())
        #endif
        .navigationTitle("Sign in")
        .alert(
            "Something Went Wrong",
            isPresented: .init(get: {
                error != nil
            }, set: { isPresented in
                if !isPresented {
                    error = nil
                }
            }),
            actions: {
                Button("OK") {
                    error = nil
                }
            },
            message: {
                Text("Try again later")
            }
        )
    }
}

#Preview {
    SignInView().environment(RootViewModel())
}
