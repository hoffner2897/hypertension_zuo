//
//  HealthConnectView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct HealthConnectView: View {
    let onConnect: () -> Void
    let onSkip: () -> Void
    @StateObject private var viewModel = HealthKitSummaryViewModel()

    private let dataTypes = [
        ("年龄", "person.crop.circle"),
        ("性别", "figure.stand"),
        ("身高", "ruler"),
        ("体重", "scalemass.fill"),
        ("步数", "shoeprints.fill"),
        ("运动", "figure.run"),
        ("静息心率", "heart.fill"),
        ("睡眠", "moon.zzz.fill")
    ]

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                    DSSectionHeader(
                        "连接 Apple Health",
                        subtitle: "BPHealth 可以读取 Apple Health 中的基础健康背景，帮助展示读数趋势。",
                        systemImage: "heart.text.square"
                    )

                    illustrationCard

                    if let errorMessage = viewModel.errorMessage {
                        AuthErrorBanner(message: errorMessage)
                    }

                    DSCard {
                        VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                            Text("可同步的数据")
                                .font(.headline)
                                .foregroundStyle(DSTheme.Color.textPrimary)

                            VStack(spacing: DSTheme.Spacing.small) {
                                ForEach(dataTypes, id: \.0) { item in
                                    HStack(spacing: DSTheme.Spacing.medium) {
                                        Image(systemName: item.1)
                                            .font(.headline)
                                            .foregroundStyle(DSTheme.Color.primary)
                                            .frame(width: 34, height: 34)
                                            .background(DSTheme.Color.primarySoft)
                                            .clipShape(Circle())

                                        Text(item.0)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(DSTheme.Color.textPrimary)

                                        Spacer()

                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.headline)
                                            .foregroundStyle(DSTheme.Color.success)
                                    }
                                }
                            }
                        }
                    }

                    VStack(spacing: DSTheme.Spacing.small) {
                        DSPrimaryButton(
                            "连接 Apple Health",
                            systemImage: "link",
                            isLoading: viewModel.isLoading,
                            isDisabled: viewModel.isPrimaryActionDisabled
                        ) {
                            Task {
                                await viewModel.requestAuthorization()
                                if viewModel.errorMessage == nil {
                                    onConnect()
                                }
                            }
                        }

                        DSSecondaryButton("暂时跳过", systemImage: "arrow.right") {
                            onSkip()
                        }
                    }
                }
                .padding(DSTheme.Spacing.large)
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var illustrationCard: some View {
        DSCard {
            HStack(spacing: DSTheme.Spacing.large) {
                ZStack {
                    Circle()
                        .fill(DSTheme.Color.primarySoft)
                        .frame(width: 96, height: 96)

                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(DSTheme.Color.primary)
                }

                VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
                    DSChip("HealthKit", systemImage: "heart.text.square")

                    Text(viewModel.statusTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textPrimary)

                    Text(viewModel.statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthConnectView(onConnect: {}, onSkip: {})
    }
}
