//
//  StandByMargins.swift
//
//  Created by Kyle Bashour on 8/29/23.
//

import SwiftUI

extension View {
    func standByMargins() -> some View {
        modifier(StandByMargins())
    }
}

private struct StandByMargins: ViewModifier {
    @Environment(\.widgetContentMargins) private var margins

    private var isInStandby: Bool {
        margins.leading > 0 && margins.leading < 5
    }

    func body(content: Content) -> some View {
        return content.padding(EdgeInsets(
            top: 0,
            leading: 0,
            bottom: isInStandby ? margins.bottom : 0,
            trailing: 0
        ))
    }
}
