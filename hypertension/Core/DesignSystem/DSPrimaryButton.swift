//
//  DSPrimaryButton.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct DSPrimaryButton: View {
    let title: String
    let systemImage: String?
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSTheme.Spacing.small) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                }

                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, DSTheme.Spacing.medium)
            .background(isDisabled ? DSTheme.Color.textSecondary.opacity(0.35) : DSTheme.Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: 16) {
        DSPrimaryButton("Continue", systemImage: "arrow.right") {}
        DSPrimaryButton("Reviewing", isLoading: true) {}
        DSPrimaryButton("Disabled", systemImage: "lock", isDisabled: true) {}
    }
    .padding()
    .background(DSTheme.Color.appBackground)
}
