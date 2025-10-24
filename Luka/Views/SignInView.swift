//
//  ContentView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import WidgetKit
import Dexcom

struct SignInView: View {
    @Environment(RootViewModel.self) private var viewModel

    private let locations: [AccountLocation] = [
        .usa,
        .apac,
        .worldwide,
    ]

    var body: some View {
        NavigationStack {
            #if os(iOS)
            content
            #else
            ScrollView {
                content
            }
            #endif
        }
    }

    private var content: some View {
        VStack(alignment: .leading) {
            Spacer()

            (Text("Welcome to") + Text("\nLuka").foregroundStyle(.accent))
            #if os(iOS)
                .font(.largeTitle.weight(.heavy))
            #else
                .font(.title2.weight(.heavy))
            #endif

            Spacer()

            #if os(watchOS)
            Text("Select an account location to get started")
                .foregroundStyle(.secondary)
                .padding(.vertical)
            #endif

            Group {
                #if os(iOS)
                FormSection {
                    locationLinks
                }
                .padding(.vertical)
                #else
                locationLinks
                #endif
            }
            .navigationDestination(for: AccountLocation.self) { accountLocation in
                UsernamePasswordView(accountLocation: accountLocation)
            }

            #if os(iOS)
            Text("Select an account location to get started")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .fontDesign(.rounded)
    }

    private var locationLinks: some View {
        ForEach(locations) { accountLocation in
            NavigationLink(value: accountLocation) {
                FormRow(title: accountLocation.displayName) {
                    Image(systemName: "chevron.right")
                }
            }

            #if os(iOS)
            if accountLocation != locations.last {
                FormSectionDivider()
            }
            #endif
        }
    }
}

extension AccountLocation: @retroactive Identifiable {
    public var id: Self { self }

    var displayName: String {
        switch self {
        case .usa:
            "United States"
        case .apac:
            "Japan"
        case .worldwide:
            "Anywhere Else"
        }
    }
}

private struct UsernamePasswordView: View {
    var accountLocation: AccountLocation

    @Environment(RootViewModel.self) private var viewModel

    @State private var error: Error?
    @State private var isSigningIn = false
    @State private var username = ""
    @State private var password = ""

    @FocusState private var isUsernameFocused

    var body: some View {
        FooterScrollView {
            VStack(alignment: .leading) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    #if os(iOS)
                    .focused($isUsernameFocused)
                    .keyboardType(.emailAddress)
                    #endif

                SecureField("Password", text: $password)
                    .textContentType(.password)

                VStack(alignment: .leading) {
                    Divider().padding(.vertical, 10)

                    Text("Sign in using your Dexcom username and password. **Dexcom share must be enabled with at least one follower**, but sign in using **your own Dexcom credentials**, not the followers. If your username is a phone number, format it with a + and the area code, for example +12223334444.\n\nLuka is not owned by or affiliated with Dexcom. Your username and password are stored securely in iCloud Keychain.")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
            }
            .padding()
        } footer: {
            Button {
                Task<Void, Never> {
                    isSigningIn = true

                    do {
                        try await viewModel.signIn(
                            username: username,
                            password: password,
                            accountLocation: accountLocation
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
            .modifier {
                if #available(iOS 26, *), #available(watchOS 26, *) {
                    $0.buttonStyle(.glassProminent)
                } else {
                    $0.buttonStyle(.borderedProminent)
                }
            }
            .buttonBorderShape(.capsule)
            .padding()
        }
        #if os(iOS)
        .textFieldStyle(CardTextFieldStyle())
        #endif
        .navigationTitle("Sign In")
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
                Text("Try again in a few minutes")
            }
        )
        .task {
            isUsernameFocused = true
        }
        .fontDesign(.rounded)
    }
}

#Preview {
    SignInView().environment(RootViewModel())
}
