//
//  LukaWidgetPushHandler.swift
//  Luka
//
//  Created by Claude on 12/20/25.
//

import Foundation
import WidgetKit
import Defaults
import KeychainAccess
import TelemetryDeck
import Dexcom

#if canImport(WidgetKit)
@available(iOS 19.0, watchOS 11.0, *)
struct LukaWidgetPushHandler: WidgetPushHandler {
    private let username = Keychain.shared.username
    private let accountLocation: AccountLocation? = Defaults[.accountLocation]

    func pushTokenDidChange(for pushTokens: [WidgetPushToken]) async {
        guard let username, let accountLocation else {
            return
        }

        // Skip for demo account
        guard username != DexcomHelper.mockEmail else {
            return
        }

        // Convert push tokens to hex strings
        let tokenStrings = pushTokens.map { token in
            token.map { String(format: "%02x", $0) }.joined()
        }

        await sendWidgetPushTokens(
            tokens: tokenStrings,
            username: username,
            accountLocation: accountLocation
        )

        TelemetryDeck.signal(
            "Widget.pushTokensUpdated",
            parameters: ["count": String(tokenStrings.count)]
        )
    }

    private func sendWidgetPushTokens(
        tokens: [String],
        username: String,
        accountLocation: AccountLocation
    ) async {
        let payload = WidgetPushTokenRequest(
            pushTokens: tokens,
            environment: .current,
            username: username,
            accountLocation: accountLocation
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        var request = URLRequest(url: URL(string: "https://a1c.dev/widget-push-tokens")!)
        request.httpMethod = "POST"
        request.httpBody = try? encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let _ = try await URLSession.shared.data(for: request)
            TelemetryDeck.signal("Widget.sentPushTokens")
        } catch {
            TelemetryDeck.signal(
                "Widget.failedToSendPushTokens",
                parameters: ["error": error.localizedDescription]
            )
        }
    }
}

#endif
