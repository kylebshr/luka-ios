//
//  Data+G7.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
//

import Foundation

extension Data {
    var hexadecimalString: String {
        return map { String(format: "%02x", $0) }.joined()
    }

    func to<T: FixedWidthInteger>(_ type: T.Type) -> T {
        return withUnsafeBytes { $0.loadUnaligned(as: type) }
    }

    func toInt<T: FixedWidthInteger>() -> T {
        return to(T.self)
    }
}

extension Data {
    init(_ value: some FixedWidthInteger) {
        var value = value
        self = Swift.withUnsafeBytes(of: &value) { Data($0) }
    }
}
