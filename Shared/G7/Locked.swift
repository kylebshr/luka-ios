//
//  Locked.swift
//  Luka
//
//  Thread-safe value wrapper, replacing LoopKit's Locked<T>.
//

import Foundation
import os

final class Locked<T>: @unchecked Sendable {
    private var _value: T
    private let lock = OSAllocatedUnfairLock()

    init(_ value: T) {
        _value = value
    }

    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}
