//
//  DSCard.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct DSCard<Content: View>: View {
    var padding: CGFloat = DSTheme.Spacing.medium
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSTheme.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.large, style: .continuous))
            .shadow(color: DSTheme.cardShadow, radius: 14, x: 0, y: 8)
    }
}

#Preview {
    DSCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(DSTheme.Color.textPrimary)
            Text("Your latest reading will appear here.")
                .font(.subheadline)
                .foregroundStyle(DSTheme.Color.textSecondary)
        }
    }
    .padding()
    .background(DSTheme.Color.appBackground)
}
