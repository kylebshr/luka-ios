//
//  AppDelegate.swift
//  Luka
//
//  Created by Kyle Bashour on 6/5/26.
//

import UIKit
import TelemetryDeck

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// Handles redirect deep links as early in the launch lifecycle as the system allows.
///
/// Widget taps always open Luka first, then Luka re-opens the target app (Dexcom,
/// Sugarmate, etc.). Catching the URL at scene-connection time — rather than waiting
/// for SwiftUI's `onOpenURL`, which fires only after the view hierarchy renders — lets
/// us hand off as soon as possible.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // SwiftUI manages the window itself; we only need the launch URLs. Don't
        // create a window here, or SwiftUI's content won't be installed.
        handle(connectionOptions.urlContexts)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handle(URLContexts)
    }

    private func handle(_ contexts: Set<UIOpenURLContext>) {
        guard
            let url = contexts.first?.url,
            let target = LaunchableApp.externalRedirect(for: url)
        else {
            return
        }

        UIApplication.shared.open(target.url)
        TelemetryDeck.signal("Redirect.launched", parameters: ["app": target.rawValue])
    }
}
