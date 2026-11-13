//
//  AccountEntity.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import AppIntents
import Foundation

/// A signed-in Dexcom account, for choosing which one a widget shows or which
/// one's Live Activity to start or end.
struct AccountEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Account"
    static let defaultQuery = AccountEntityQuery()

    var id: DexcomAccount.ID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ account: DexcomAccount, store: AccountStore = .shared) {
        id = account.id
        name = store.displayName(for: account)
    }

    init(id: DexcomAccount.ID, name: String) {
        self.id = id
        self.name = name
    }
}

struct AccountEntityQuery: EntityQuery {
    func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        AccountStore.shared.accounts
            .filter { identifiers.contains($0.id) }
            .map { AccountEntity($0) }
    }

    func suggestedEntities() async throws -> [AccountEntity] {
        AccountStore.shared.accounts.map { AccountEntity($0) }
    }
}

/// A widget configuration with a list of accounts to show. See
/// `AccountResolution.widgetAccounts` for how it resolves.
protocol AccountWidgetConfiguration: WidgetConfigurationIntent {
    var accounts: [AccountEntity]? { get }
}
