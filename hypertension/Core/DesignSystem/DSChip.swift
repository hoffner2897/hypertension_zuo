//
//  DSChip.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct DSChip: View {
    let title: String
    let systemImage: String?
    let tint: Color
    var isSelected = false

    init(
        _ title: String,
        systemImage: String? = nil,
        tint: Color = DSTheme.Color.primary,
        isSelected: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: DSTheme.Spacing.xSmall) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }

            Text(L10n.string(title))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(isSelected ? .white : tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? tint : tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        DSChip("Connected", systemImage: "checkmark.circle.fill", tint: DSTheme.Color.success, isSelected: true)
        DSChip("Mock data", systemImage: "sparkles")
        DSChip("Attention", systemImage: "exclamationmark.triangle.fill", tint: DSTheme.Color.warning)
    }
    .padding()
    .background(DSTheme.Color.appBackground)
}
