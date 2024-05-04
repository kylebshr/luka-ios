//
//  DataManager.swift
//  Hako
//
//  Created by Kyle Bashour on 3/4/24.
//

import Foundation

struct DiskCache {
    static func load<Value>(_ key: DiskCacheKey<Value>) throws -> Value {
        let data = try Data(contentsOf: key.url)
        return try PropertyListDecoder().decode(Value.self, from: data)
    }

    static func save<Value: Codable>(_ value: Value, for key: DiskCacheKey<Value>) throws {
        let data = try PropertyListEncoder().encode(value)
        try data.write(to: key.url)
    }
}

struct DiskCacheKey<Value: Codable> {
    var name: String

    var url: URL {
        .documentsDirectory.appending(component: name)
    }
}
