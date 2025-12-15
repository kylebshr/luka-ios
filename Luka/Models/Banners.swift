//
//  Banners.swift
//  Luka
//
//  Created by Kyle Bashour on 12/14/25.
//

import Foundation

struct Banners: Codable {
    var banners: [Banner]
}

struct Banner: Codable {
    var id: String
    var title: String?
    var body: String?
}
