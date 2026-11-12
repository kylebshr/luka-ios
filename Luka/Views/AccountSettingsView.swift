//
//  AccountSettingsView.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Dexcom
import SwiftUI
import TelemetryDeck
import WidgetKit

/// Rename an account, see its details, or sign out of it.
struct AccountSettingsView: View {
    var account: DexcomAccount

    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var isConfirmingSignOut = false
    @FocusState private var isNameFocused: Bool

    init(account: DexcomAccount) {
        self.account = account
        _name = State(initialValue: account.displayName)
    }

    private var username: String {
        viewModel.username(for: account) ?? ""
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name, prompt: Text(username))
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit(saveName)
            } header: {
                Text("Name")
            } footer: {
                Text("Shown in the app instead of the username, like “Mom” or “Alex”.")
            }

            Section {
                LabeledContent("Username", value: username)
                LabeledContent("Region") {
                    Text(account.accountLocation.displayName)
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    isConfirmingSignOut = true
                }
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .confirmationDialog(
                    "Sign out of \(viewModel.displayName(for: account))?",
                    isPresented: $isConfirmingSignOut,
                    titleVisibility: .visible
                ) {
                    Button("Sign Out", role: .destructive, action: signOut)
                } message: {
                    if viewModel.accounts.count == 1 {
                        Text("This is your only account, so you’ll return to the sign-in screen.")
                    } else {
                        Text("Its readings will no longer appear in Luka or its widgets.")
                    }
                }
            }
        }
        .navigationTitle(viewModel.displayName(for: account))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isNameFocused) {
            if !isNameFocused {
                saveName()
            }
        }
        .onDisappear(perform: saveName)
        .fontDesign(.rounded)
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // The account may have been signed out, or the name unchanged.
        guard let current = viewModel.accounts.first(where: { $0.id == account.id }),
              current.displayName != trimmed else { return }
        viewModel.rename(account, to: trimmed)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func signOut() {
        Task {
            // Before removing the account: the server is told under its username,
            // which is gone once the credentials are deleted.
            await LiveActivityManager.shared.endLiveActivities(for: account)
            viewModel.signOut(account)
            WidgetCenter.shared.reloadAllTimelines()
            TelemetryDeck.signal("Account.removed", parameters: ["accountCount": String(viewModel.accounts.count)])
            dismiss()
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var viewModel = PreviewAccounts.rootViewModel(names: ["Mom", "Alex"])

    NavigationStack {
        AccountSettingsView(account: viewModel.accounts[0])
    }
    .environment(viewModel)
}
#endif
