//
//  AlgorithmState.swift
//  Luka
//
//  Adapted from G7SensorKit - Sensor algorithm state
//

import Foundation

public enum AlgorithmState: RawRepresentable, Equatable, CustomStringConvertible, Sendable {
    public typealias RawValue = UInt8

    public enum State: RawValue, Sendable {
        case stopped = 1
        case warmup = 2
        case ok = 6
        case questionMarks = 18
        case expired = 24
        case sensorFailed = 25
    }

    case known(State)
    case unknown(RawValue)

    public init(rawValue: RawValue) {
        guard let state = State(rawValue: rawValue) else {
            self = .unknown(rawValue)
            return
        }
        self = .known(state)
    }

    public var rawValue: RawValue {
        switch self {
        case .known(let state):
            return state.rawValue
        case .unknown(let rawValue):
            return rawValue
        }
    }

    public var sensorFailed: Bool {
        guard case .known(let state) = self else { return false }
        return state == .sensorFailed
    }

    public var isInWarmup: Bool {
        guard case .known(let state) = self else { return false }
        return state == .warmup
    }

    public var isInSensorError: Bool {
        guard case .known(let state) = self else { return false }
        return state == .questionMarks
    }

    public var hasReliableGlucose: Bool {
        guard case .known(let state) = self else { return false }
        return state == .ok
    }

    public var description: String {
        switch self {
        case .known(let state):
            return String(describing: state)
        case .unknown(let value):
            return ".unknown(\(value))"
        }
    }
}
