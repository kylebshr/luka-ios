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
//        #if DEBUG
//        return .local
//        #endif
        return .production
    }

    var baseURL: URL {
        switch self {
        case .production:
            URL(string: "https://luka-vapor-v2.fly.dev")!
        case .local:
            URL(string: "http://localhost:8080")!
        }
    }

    func url(for path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }
}
