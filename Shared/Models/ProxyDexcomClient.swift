//
//  ProxyDexcomClient.swift
//  Luka
//
//  Created by Claude on 5/23/26.
//

import Dexcom
import Foundation

/// Fetches readings from the Luka server's cached `glucose-readings` endpoint
/// and falls back to the wrapped client when the server has no cached data.
final class ProxyDexcomClient: DexcomClientService, @unchecked Sendable {
    private let underlying: DexcomClientService
    private let username: String
    private let password: String
    private let client: HTTPClient
    private let decoder: JSONDecoder

    init(
        wrapping underlying: DexcomClientService,
        username: String,
        password: String,
        client: HTTPClient = HTTPClient()
    ) {
        self.underlying = underlying
        self.username = username
        self.password = password
        self.client = client

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func setDelegate(_ delegate: DexcomClientDelegate?) async {
        await underlying.setDelegate(delegate)
    }

    func getGlucoseReadings(
        duration: Measurement<UnitDuration>,
        maxCount: Int
    ) async throws -> [GlucoseReading] {
        let minutes = max(1, Int(duration.converted(to: .minutes).value.rounded()))
        return try await withFallback {
            try await fetchFromProxy(minutes: minutes, maxCount: maxCount)
        } fallback: {
            try await underlying.getGlucoseReadings(duration: duration, maxCount: maxCount)
        }
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        try await withFallback {
            try await fetchFromProxy(minutes: 15, maxCount: 1).last
        } fallback: {
            try await underlying.getLatestGlucoseReading()
        }
    }

    func getCurrentGlucoseReading() async throws -> GlucoseReading? {
        try await withFallback {
            try await fetchFromProxy(minutes: 15, maxCount: 1).last
        } fallback: {
            try await underlying.getCurrentGlucoseReading()
        }
    }

    func createSession() async throws -> (accountID: UUID, sessionID: UUID) {
        try await underlying.createSession()
    }

    /// Falls back to Dexcom on any proxy failure, not just a 404 (no session on this
    /// backend, e.g. right after a backend switch while the Live Activity is still on the
    /// other one): an unreachable or failing backend mustn't cost the user their readings.
    private func withFallback<T>(
        _ proxy: () async throws -> T,
        fallback: () async throws -> T
    ) async throws -> T {
        do {
            return try await proxy()
        } catch {
            try Task.checkCancellation()
            return try await fallback()
        }
    }

    private func fetchFromProxy(minutes: Int, maxCount: Int) async throws -> [GlucoseReading] {
        var request = client.makeRequest("glucose-readings", query: [
            URLQueryItem(name: "minutes", value: String(minutes)),
            URLQueryItem(name: "maxCount", value: String(maxCount)),
        ])
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")

        let (data, http) = try await client.send(request)

        guard (200..<300).contains(http.statusCode) else {
            throw HTTPClient.StatusError(statusCode: http.statusCode)
        }

        return try decoder.decode([GlucoseReading].self, from: data)
            .sorted { $0.date < $1.date }
    }
}
