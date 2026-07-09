//
//  DSInputRow.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct DSInputRow: View {
    let title: String
    let unit: String?
    let systemImage: String?
    let placeholder: String
    let keyboardType: UIKeyboardType
    @Binding var text: String

    init(
        title: String,
        text: Binding<String>,
        unit: String? = nil,
        systemImage: String? = nil,
        placeholder: String = "",
        keyboardType: UIKeyboardType = .numberPad
    ) {
        self.title = title
        self._text = text
        self.unit = unit
        self.systemImage = systemImage
        self.placeholder = placeholder
        self.keyboardType = keyboardType
    }

    var body: some View {
        HStack(spacing: DSTheme.Spacing.medium) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(width: 32, height: 32)
                    .background(DSTheme.Color.primarySoft)
                    .clipShape(Circle())
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textPrimary)

            Spacer(minLength: DSTheme.Spacing.small)

            TextField(placeholder, text: $text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textPrimary)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboardType)
                .frame(minWidth: 56, maxWidth: 90)

            if let unit {
                Text(unit)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.textSecondary)
            }
        }
        .padding(.horizontal, DSTheme.Spacing.medium)
        .frame(minHeight: 58)
        .background(DSTheme.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSTheme.Radius.medium, style: .continuous)
                .stroke(DSTheme.Color.border, lineWidth: 1)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        DSInputRow(
            title: "Systolic",
            text: .constant("118"),
            unit: "mmHg",
            systemImage: "arrow.up.heart"
        )
        DSInputRow(
            title: "Diastolic",
            text: .constant("76"),
            unit: "mmHg",
            systemImage: "arrow.down.heart"
        )
    }
    .padding()
    .background(DSTheme.Color.appBackground)
}
