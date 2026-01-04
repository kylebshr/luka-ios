//
//  Locked.swift
//  Luka
//
//  Adapted from G7SensorKit for thread-safe state management
//

import Foundation

final class Locked<T> {
    private var _value: T
    private let lock = NSLock()

    init(_ value: T) {
        self._value = value
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

    @discardableResult
    func mutate(_ changes: (inout T) -> Void) -> T {
        lock.lock()
        defer { lock.unlock() }
        changes(&_value)
        return _value
    }
}
