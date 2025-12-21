//
//  Backend.swift
//  Luka
//
//  Created by Kyle Bashour on 12/18/25.
//

import Foundation

enum Backend {
    case production
    case local

    static var current: Self {
        #if DEBUG
        .local
        #else
        .production
        #endif
    }

    var baseURL: URL {
        switch self {
        case .production:
            URL(string: "https://a1c.dev")!
        case .local:
            URL(string: "http://localhost:8080")!
        }
    }

    func url(for path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }
}
