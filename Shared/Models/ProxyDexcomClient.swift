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
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        wrapping underlying: DexcomClientService,
        username: String,
        password: String,
        baseURL: URL = Backend.current.baseURL,
        session: URLSession = .shared
    ) {
        self.underlying = underlying
        self.username = username
        self.password = password
        self.baseURL = baseURL
        self.session = session

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
        do {
            return try await fetchFromProxy(minutes: minutes, maxCount: maxCount)
        } catch ProxyError.notFound {
            return try await underlying.getGlucoseReadings(duration: duration, maxCount: maxCount)
        }
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        do {
            return try await fetchFromProxy(minutes: 15, maxCount: 1).last
        } catch ProxyError.notFound {
            return try await underlying.getLatestGlucoseReading()
        }
    }

    func getCurrentGlucoseReading() async throws -> GlucoseReading? {
        do {
            return try await fetchFromProxy(minutes: 15, maxCount: 1).last
        } catch ProxyError.notFound {
            return try await underlying.getCurrentGlucoseReading()
        }
    }

    func createSession() async throws -> (accountID: UUID, sessionID: UUID) {
        try await underlying.createSession()
    }

    private enum ProxyError: Error {
        case notFound
        case invalidResponse(Int)
    }

    private func fetchFromProxy(minutes: Int, maxCount: Int) async throws -> [GlucoseReading] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("glucose-readings"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "minutes", value: String(minutes)),
            URLQueryItem(name: "maxCount", value: String(maxCount)),
        ]

        var request = URLRequest(url: components.url!)
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProxyError.invalidResponse(-1)
        }

        if http.statusCode == 404 {
            throw ProxyError.notFound
        }

        guard (200..<300).contains(http.statusCode) else {
            throw ProxyError.invalidResponse(http.statusCode)
        }

        return try decoder.decode([GlucoseReading].self, from: data)
            .sorted { $0.date < $1.date }
    }
}
