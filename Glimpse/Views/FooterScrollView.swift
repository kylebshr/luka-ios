//
//  FooterScrollView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/28/24.
//

import SwiftUI

struct FooterScrollView<Content: View, Footer: View>: View {
    var showsIndicators: Bool
    var content: Content
    var footer: Footer

    @State private var footerBackgroundOpacity: CGFloat = 0

    init(
        showsIndicators: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.showsIndicators = showsIndicators
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            content.background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: Frames.self,
                        value: .init(content: proxy.frame(in: .global))
                    )
                }
            }

            #if os(watchOS)
            footer
            #endif
        }
        #if os(iOS)
        .safeAreaInset(edge: .bottom) {
            if Footer.self != EmptyView.self {
                footer
                    .background {
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(Material.bar)
                                .overlay(alignment: .top) {
                                    Divider()
                                }
                                .ignoresSafeArea(.all, edges: .bottom)
                                .opacity(footerBackgroundOpacity)
                                .preference(
                                    key: Frames.self,
                                    value: .init(footer: proxy.frame(in: .global))
                                )
                        }
                    }
            }
        }
        .onPreferenceChange(Frames.self) { frames in
            guard let footer = frames.footer, let content = frames.content else {
                return
            }

            let intersection = footer.intersection(content).height
            let opacity = min(intersection, 10) / 10
            if opacity != footerBackgroundOpacity {
                footerBackgroundOpacity = opacity
            }
        }
        #endif
    }
}

private struct Frames: PreferenceKey {
    static var defaultValue: Rects = .init()

    static func reduce(value: inout Rects, nextValue: () -> Rects) {
        let next = nextValue()
        if let content = next.content {
            value.content = content
        }

        if let footer = next.footer {
            value.footer = footer
        }
    }
}

private struct Rects: Equatable {
    var content: CGRect?
    var footer: CGRect?
}
