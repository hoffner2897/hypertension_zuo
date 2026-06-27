//
//  DSLoadingIndicator.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct DSLoadingIndicator: View {
    let title: String
    let message: String?

    init(
        title: String = "Loading",
        message: String? = nil
    ) {
        self.title = title
        self.message = message
    }

    var body: some View {
        DSCard {
            VStack(spacing: DSTheme.Spacing.medium) {
                ProgressView()
                    .controlSize(.large)
                    .tint(DSTheme.Color.primary)

                VStack(spacing: DSTheme.Spacing.xSmall) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(DSTheme.Color.textPrimary)
                        .multilineTextAlignment(.center)

                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(DSTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    DSLoadingIndicator(
        title: "Reviewing this reading",
        message: "This local mock analysis will help prepare the result screen."
    )
    .padding()
    .background(DSTheme.Color.appBackground)
}
