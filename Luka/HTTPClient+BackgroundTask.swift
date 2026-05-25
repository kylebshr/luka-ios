//
//  HTTPClient+BackgroundTask.swift
//  Luka
//
//  Created by Claude on 5/25/26.
//

import Foundation
import UIKit

extension HTTPClient {
    /// Runs `work` inside a `UIApplication` background task so the call
    /// finishes even if the app is suspended mid-flight.
    @MainActor
    func withBackgroundTask(name: String, _ work: () async -> Void) async {
        let taskID = UIApplication.shared.beginBackgroundTask(withName: name)
        await work()
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
}
