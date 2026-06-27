//
//  DSSecondaryButton.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct DSSecondaryButton: View {
    let title: String
    let systemImage: String?
    var isDisabled = false
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSTheme.Spacing.small) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                }

                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isDisabled ? DSTheme.Color.textSecondary : DSTheme.Color.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, DSTheme.Spacing.medium)
            .background(DSTheme.Color.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                    .stroke(DSTheme.Color.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: 16) {
        DSSecondaryButton("Enter Manually", systemImage: "square.and.pencil") {}
        DSSecondaryButton("Disabled", systemImage: "lock", isDisabled: true) {}
    }
    .padding()
    .background(DSTheme.Color.appBackground)
}
