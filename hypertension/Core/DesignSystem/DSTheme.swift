//
//  DSTheme.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

enum DSTheme {
    enum Color {
        static let appBackground = SwiftUI.Color(red: 0.94, green: 0.97, blue: 1.0)
        static let cardBackground = SwiftUI.Color.white
        static let primary = SwiftUI.Color(red: 0.08, green: 0.39, blue: 0.82)
        static let primarySoft = SwiftUI.Color(red: 0.86, green: 0.93, blue: 1.0)
        static let textPrimary = SwiftUI.Color(red: 0.08, green: 0.11, blue: 0.16)
        static let textSecondary = SwiftUI.Color(red: 0.38, green: 0.45, blue: 0.55)
        static let border = SwiftUI.Color(red: 0.86, green: 0.90, blue: 0.95)
        static let success = SwiftUI.Color(red: 0.08, green: 0.55, blue: 0.32)
        static let warning = SwiftUI.Color(red: 0.86, green: 0.42, blue: 0.12)
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
    }

    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    static let cardShadow = SwiftUI.Color.black.opacity(0.06)
}
