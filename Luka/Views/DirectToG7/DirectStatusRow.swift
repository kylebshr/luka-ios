//
//  DirectStatusRow.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import DexcomKit
import SwiftUI

/// Compact connection/session status shown on the main screen in Direct to
/// G7 mode: an indicator dot plus the most relevant fact — warming up,
/// expiring soon, or the connection state.
struct DirectStatusRow: View {
    private var manager: DirectToG7Manager { .shared }

    var body: some View {
        if let monitor = manager.monitor {
            HStack(spacing: .spacing4) {
                Circle()
                    .fill(monitor.connectionState.indicatorColor)
                    .frame(width: 8, height: 8)

                statusText(for: monitor)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
        }
    }

    @ViewBuilder
    private func statusText(for monitor: G7SensorMonitor) -> some View {
        if let session = monitor.session, session.isInWarmup(at: .now) {
            Text("Warming up until \(session.warmupEndDate.formatted(date: .omitted, time: .shortened))")
        } else if let session = monitor.session, expiresSoon(session) {
            Text("Sensor expires \(session.expirationDate.formatted(.relative(presentation: .named)))")
        } else {
            Text(monitor.connectionState.text)
        }
    }

    private func expiresSoon(_ session: SensorSession) -> Bool {
        session.expirationDate.timeIntervalSinceNow < 24 * 60 * 60
    }
}
