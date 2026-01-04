//
//  BluetoothServices.swift
//  Luka
//
//  Adapted from G7SensorKit - Dexcom G7 BLE service/characteristic UUIDs
//

import CoreBluetooth

protocol CBUUIDRawValue: RawRepresentable {}
extension CBUUIDRawValue where RawValue == String {
    var cbUUID: CBUUID {
        return CBUUID(string: rawValue)
    }
}

enum SensorServiceUUID: String, CBUUIDRawValue {
    case deviceInfo = "180A"
    case advertisement = "FEBC"
    case cgmService = "F8083532-849E-531C-C594-30F1F86A4EA5"
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
