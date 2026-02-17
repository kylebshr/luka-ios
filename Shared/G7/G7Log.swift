//
//  G7Log.swift
//  Luka
//
//  Logging utilities for G7 BLE layer. Replaces LoopKit's OSLog extension.
//

import os.log

extension OSLog {
    convenience init(g7Category: String) {
        self.init(subsystem: "com.kylebashour.Luka.G7", category: g7Category)
    }

    func g7Debug(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .debug, args)
    }

    func g7Info(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .info, args)
    }

    func g7Default(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .default, args)
    }

    func g7Error(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .error, args)
    }

    private func log(_ message: StaticString, type: OSLogType, _ args: [CVarArg]) {
        switch args.count {
        case 0:
            os_log(message, log: self, type: type)
        case 1:
            os_log(message, log: self, type: type, args[0])
        case 2:
            os_log(message, log: self, type: type, args[0], args[1])
        case 3:
            os_log(message, log: self, type: type, args[0], args[1], args[2])
        case 4:
            os_log(message, log: self, type: type, args[0], args[1], args[2], args[3])
        case 5:
            os_log(message, log: self, type: type, args[0], args[1], args[2], args[3], args[4])
        default:
            os_log(message, log: self, type: type, args)
        }
    }
}
