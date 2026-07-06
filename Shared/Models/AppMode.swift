//
//  AppMode.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import Foundation

/// How the app sources glucose data.
enum AppMode: String, Codable, Defaults.Serializable {
    /// Dexcom Share: readings come from Dexcom's servers using the user's
    /// Share credentials.
    case cloud

    /// Direct to G7: readings come straight from the sensor over Bluetooth
    /// on this device, riding alongside the official Dexcom app's session.
    case direct
}
