//
//  Data+G7.swift
//  Luka
//
//  Adapted from G7SensorKit for BLE glucose reading
//

import Foundation

extension Data {
    private func toDefaultEndian<T: FixedWidthInteger>(_: T.Type) -> T {
        return self.withUnsafeBytes({ (rawBufferPointer: UnsafeRawBufferPointer) -> T in
            let bufferPointer = rawBufferPointer.bindMemory(to: T.self)
            guard let pointer = bufferPointer.baseAddress else {
                return 0
            }
            return T(pointer.pointee)
        })
    }

    func to<T: FixedWidthInteger>(_ type: T.Type) -> T {
        return T(littleEndian: toDefaultEndian(type))
    }

    func toInt<T: FixedWidthInteger>() -> T {
        return to(T.self)
    }

    var hexadecimalString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
