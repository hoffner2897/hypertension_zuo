//
//  DSMetricCard.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct DSMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String?
    let tint: Color
    let subtitle: String?

    init(
        title: String,
        value: String,
        unit: String,
        systemImage: String? = nil,
        tint: Color = DSTheme.Color.primary,
        subtitle: String? = nil
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.systemImage = systemImage
        self.tint = tint
        self.subtitle = subtitle
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                HStack(spacing: DSTheme.Spacing.small) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: 28, height: 28)
                            .background(tint.opacity(0.12))
                            .clipShape(Circle())
                    }

                    Text(L10n.string(title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(DSTheme.Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(L10n.string(unit))
                        .font(.headline)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .lineLimit(1)
                }

                if let subtitle {
                    Text(L10n.string(subtitle))
                        .font(.footnote)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DSMetricCard(
            title: "Systolic",
            value: "118",
            unit: "mmHg",
            systemImage: "heart.text.square",
            subtitle: "Latest sample reading"
        )

        DSMetricCard(
            title: "Pulse",
            value: "72",
            unit: "bpm",
            systemImage: "waveform.path.ecg",
            tint: DSTheme.Color.success
        )
    }
    .padding()
    .background(DSTheme.Color.appBackground)
}
