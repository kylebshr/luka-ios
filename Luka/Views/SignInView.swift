//
//  ContentView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import WidgetKit
import Dexcom

/// A choice on the sign-in landing screen: a Dexcom account location, or a
/// LibreLinkUp account for FreeStyle Libre sensors.
enum SignInDestination: Hashable {
    case dexcom(AccountLocation)
    case libre

    var provider: CGMProvider {
        switch self {
        case .dexcom: .dexcom
        case .libre: .libre
        }
    }

    var accountLocation: AccountLocation? {
        switch self {
        case .dexcom(let accountLocation): accountLocation
        case .libre: nil
        }
    }
}

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
            (Text("Welcome to") + Text(verbatim: " ") + Text("Luka").foregroundStyle(.accent))
            #if os(iOS)
                .font(.largeTitle.weight(.bold))
                .padding(.top, 64)
            #else
                .font(.title2.weight(.bold))
            #endif

            #if os(iOS)
            Text("Excellent widgets and Live Activities for Dexcom and FreeStyle Libre continuous glucose monitors.")
                .foregroundStyle(.secondary)
            #endif

            Spacer()

            #if os(watchOS)
            Text("Select your Dexcom account location, or sign in with LibreLinkUp")
                .foregroundStyle(.secondary)
                .padding(.vertical)
            #endif

            Group {
                #if os(iOS)
                FormSection {
                    destinationLinks
                }
                .padding(.vertical)
                #else
                destinationLinks
                #endif
            }
            .navigationDestination(for: SignInDestination.self) { destination in
                UsernamePasswordView(destination: destination)
            }

            #if os(iOS)
            Text("Select your Dexcom account location, or sign in with LibreLinkUp for FreeStyle Libre")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .withReadableWidth()
        .padding()
        .fontDesign(.rounded)
    }

    @ViewBuilder private var destinationLinks: some View {
        ForEach(locations) { accountLocation in
            NavigationLink(value: SignInDestination.dexcom(accountLocation)) {
                FormRow(title: accountLocation.displayName) {
                    Image(systemName: "chevron.right")
                }
            }

            #if os(iOS)
            FormSectionDivider()
            #endif
        }

        NavigationLink(value: SignInDestination.libre) {
            FormRow(title: "LibreLinkUp") {
                Image(systemName: "chevron.right")
            }
        }
    }
}

extension AccountLocation: @retroactive Identifiable {
    public var id: Self { self }

    var displayName: LocalizedStringKey {
        switch self {
        case .usa:
            "Dexcom – United States"
        case .apac:
            "Dexcom – Japan"
        case .worldwide:
            "Dexcom – Anywhere Else"
        }
    }
}

private struct UsernamePasswordView: View {
    var destination: SignInDestination

    @Environment(RootViewModel.self) private var viewModel

    @State private var error: Error?
    @State private var isSigningIn = false
    @State private var username = ""
    @State private var password = ""

    @FocusState private var isUsernameFocused

    private var usernameTitle: LocalizedStringKey {
        switch destination {
        case .dexcom: "Username"
        case .libre: "Email"
        }
    }

    private var footerText: LocalizedStringKey {
        switch destination {
        case .dexcom:
            "Sign in using your Dexcom username and password. **Dexcom share must be enabled with at least one follower**, but sign in using **your own Dexcom credentials**, not the followers. If your username is a phone number, format it with a + and the area code, for example +12223334444."
        case .libre:
            "Sign in using a LibreLinkUp account that follows your sensor. To set one up, create a [LibreLinkUp](https://www.librelinkup.com) account, then invite it from the Libre app under **Share → Connected Apps → LibreLinkUp**, and accept the invitation in the LibreLinkUp app."
        }
    }

    var body: some View {
        FooterScrollView {
            VStack(alignment: .leading) {
                TextField(usernameTitle, text: $username)
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

                    Text(footerText)
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
            }
            .withReadableWidth()
            .padding()
        } footer: {
            Button {
                Task<Void, Never> {
                    isSigningIn = true

                    do {
                        try await viewModel.signIn(
                            provider: destination.provider,
                            username: username,
                            password: password,
                            accountLocation: destination.accountLocation
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
            .withReadableWidth()
            .padding()
            .disabled(username.isEmpty || password.isEmpty)
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
