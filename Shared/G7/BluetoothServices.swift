//
//  BluetoothServices.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
//

import CoreBluetooth

protocol CBUUIDRawValue: RawRepresentable {}
extension CBUUIDRawValue where RawValue == String {
    var cbUUID: CBUUID {
        return CBUUID(string: rawValue)
    }
}

enum SensorServiceUUID: String, CBUUIDRawValue {
    case advertisement = "FEBC"
    case cgmService = "F8083532-849E-531C-C594-30F1F86A4EA5"
    case serviceB = "F8084532-849E-531C-C594-30F1F86A4EA5"
}

enum CGMServiceCharacteristicUUID: String, CBUUIDRawValue {
    // Read/Notify
    case communication = "F8083533-849E-531C-C594-30F1F86A4EA5"
    // Write/Indicate
    case control = "F8083534-849E-531C-C594-30F1F86A4EA5"
    // Write/Indicate
    case authentication = "F8083535-849E-531C-C594-30F1F86A4EA5"
    // Read/Write/Notify
    case backfill = "F8083536-849E-531C-C594-30F1F86A4EA5"
}
