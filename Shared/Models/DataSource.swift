//
//  DataSource.swift
//  Luka
//
//  Created by Kyle Bashour on 2/16/26.
//

import Defaults
import Foundation

enum DataSource: String, Codable, Defaults.Serializable {
    case share
    case g7Bluetooth
}
