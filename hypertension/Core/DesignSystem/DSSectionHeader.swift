//
//  DSSectionHeader.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct DSSectionHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String?

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.primary)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string(title))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DSTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(L10n.string(subtitle))
                        .font(.subheadline)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    DSSectionHeader(
        "Blood pressure",
        subtitle: "Review your latest sample reading and trends.",
        systemImage: "heart.text.square"
    )
    .padding()
    .background(DSTheme.Color.appBackground)
}
