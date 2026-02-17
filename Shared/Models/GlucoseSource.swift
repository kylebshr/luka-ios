//
//  GlucoseSource.swift
//  Luka
//
//  Created by Kyle Bashour on 2/16/26.
//

import Dexcom
import Foundation

protocol GlucoseSource: AnyObject, Sendable {
    func getGlucoseReadings() async throws -> [GlucoseReading]
    func getLatestGlucoseReading() async throws -> GlucoseReading?
}
