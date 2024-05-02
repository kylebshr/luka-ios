//
//  EdgeInsets+Extensions.swift
//  Hako
//
//  Created by Kyle Bashour on 3/7/24.
//

import SwiftUI

extension EdgeInsets {
    init(_ all: CGFloat) {
        self.init(vertical: all, horizontal: all)
    }

    init(vertical: CGFloat, horizontal: CGFloat) {
        self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}
