//
//  HTTPClient.swift
//  Luka
//
//  Created by Claude on 5/25/26.
//

import Foundation

/// Lightweight HTTP client for the Luka backend that stamps every request
/// with the app version and build, so the server can correlate behavior
/// with the client release.
struct HTTPClient {
    var baseURL: URL
    var session: URLSession

    init(baseURL: URL = Backend.current.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Build a request to `path` with standard Luka headers applied.
    func makeRequest(_ path: String, query: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty {
            components.queryItems = query
        }
        var request = URLRequest(url: components.url!)
        let info = Bundle.main.infoDictionary
        request.setValue(info?["CFBundleShortVersionString"] as? String, forHTTPHeaderField: "X-Luka-Version")
        request.setValue(info?["CFBundleVersion"] as? String, forHTTPHeaderField: "X-Luka-Build")
        return request
    }

    /// Build a JSON-encoded POST request to `path` with standard Luka headers.
    func makePostRequest<Body: Encodable>(_ path: String, body: Body) throws -> URLRequest {
        var request = makeRequest(path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Send `request` and return the response data and HTTP response.
    @discardableResult
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
