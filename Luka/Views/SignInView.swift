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
    /// Set when adding another account from Settings: the view gets a cancel
    /// button and a name field, and dismisses itself once signed in. Nil for
    /// the signed-out root.
    var onAddAccount: ((DexcomAccount) -> Void)?

    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    private var isAddingAccount: Bool {
        onAddAccount != nil
    }

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
            Group {
                if isAddingAccount {
                    Text("Add an Account")
                } else {
                    Text("Welcome to") + Text(verbatim: " ") + Text("Luka").foregroundStyle(.accent)
                }
            }
            #if os(iOS)
                .font(.largeTitle.weight(.bold))
                .padding(.top, isAddingAccount ? .spacing8 : 64)
            #else
                .font(.title2.weight(.bold))
            #endif

            #if os(iOS)
            Group {
                if isAddingAccount {
                    Text("Follow someone else’s readings alongside your own, like a parent or child.")
                } else {
                    Text("Excellent widgets and Live Activities for Dexcom continuous glucose monitors.")
                }
            }
            .foregroundStyle(.secondary)
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
                UsernamePasswordView(accountLocation: accountLocation, onAddAccount: onAddAccount.map { onAddAccount in
                    { account in
                        onAddAccount(account)
                        dismiss()
                    }
                })
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
        .withReadableWidth()
        .padding()
        .fontDesign(.rounded)
        .toolbar {
            if isAddingAccount {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
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

    var displayName: LocalizedStringKey {
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
    var onAddAccount: ((DexcomAccount) -> Void)?

    @Environment(RootViewModel.self) private var viewModel

    @State private var error: Error?
    @State private var isSigningIn = false
    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""

    @FocusState private var isUsernameFocused

    private var isDuplicateUsername: Bool {
        if case AccountStore.StoreError.duplicateUsername? = error {
            true
        } else {
            false
        }
    }

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

                if onAddAccount != nil {
                    TextField("Name (optional)", text: $displayName, prompt: Text("Name, like “Mom” or “Alex”"))
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading) {
                    Divider().padding(.vertical, 10)

                    Text("Sign in using your Dexcom username and password. **Dexcom share must be enabled with at least one follower**, but sign in using **your own Dexcom credentials**, not the followers. If your username is a phone number, format it with a + and the area code, for example +12223334444.")
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
                        let account = try await viewModel.signIn(
                            username: username,
                            password: password,
                            accountLocation: accountLocation,
                            displayName: displayName
                        )

                        WidgetCenter.shared.reloadAllTimelines()
                        onAddAccount?(account)
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
            isDuplicateUsername ? Text("Already Signed In") : Text("Something Went Wrong"),
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
                if isDuplicateUsername {
                    Text("You’re already signed in to this Dexcom account. To follow someone else, sign in with their username and password.")
                } else {
                    Text("Try again in a few minutes")
                }
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

#if os(iOS) && DEBUG
#Preview("Add account") {
    SignInView { _ in }
        .environment(PreviewAccounts.rootViewModel(names: ["Mom"]))
}
#endif
