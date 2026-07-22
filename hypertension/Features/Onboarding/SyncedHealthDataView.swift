//
//  SyncedHealthDataView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct SyncedHealthDataView: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void
    var onResync: () -> Void = {}
    @StateObject private var viewModel = HealthKitSummaryViewModel()
    @State private var isEditingData = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        dataGridCard

                        Text("数据来源：\(viewModel.dataSourceText)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))

                        infoBanner

                        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                            AuthErrorBanner(message: errorMessage)
                        }
                    }
                }
                .padding(.horizontal, DSTheme.Spacing.large)
                .padding(.top, DSTheme.Spacing.medium)
                .padding(.bottom, 18)

                actionButtons
                    .padding(.horizontal, DSTheme.Spacing.large)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .background(.ultraThinMaterial.opacity(0.65))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.refresh()
        }
        .sheet(isPresented: $isEditingData) {
            HealthDataEditorView(draft: viewModel.makeDraft()) { draft in
                Task {
                    if await viewModel.saveManualData(draft) {
                        isEditingData = false
                    }
                }
            }
            .presentationDetents([.large])
        }
        .onChange(of: viewModel.hasRequiredData) { _, isComplete in
            if !isComplete, viewModel.errorMessage == nil {
                viewModel.errorMessage = viewModel.missingDataText
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
            HStack(alignment: .top) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .frame(width: 40, height: 40)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 4) {
                    Image("TodayHeaderAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))

                    Text("小宁")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("已同步基础数据")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("这些信息已从 Apple Health 和 Apple Watch\n自动获取。")
                    .font(.subheadline.weight(.medium))
                    .lineSpacing(4)
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
        }
    }

    private var dataGridCard: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(displayItems) { item in
                SyncedHealthMetricTile(item: item) {
                    isEditingData = true
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private var infoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.headline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.primary)

            Text("这些数据将用于后续理解血压读数。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(Color(red: 0.91, green: 0.95, blue: 1.0))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.54, green: 0.72, blue: 1.0), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    if await viewModel.completeSyncedData() {
                        onContinue()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }

                    Text("完成")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DSTheme.Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.hasRequiredData || viewModel.isLoading)
            .opacity((!viewModel.hasRequiredData || viewModel.isLoading) ? 0.58 : 1)

            Button {
                Task {
                    await viewModel.refresh()
                    onResync()
                }
            } label: {
                Text("重新同步")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(DSTheme.Color.primary, lineWidth: 1.2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)

            if viewModel.shouldOfferSettings {
                Button {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    UIApplication.shared.open(settingsURL)
                } label: {
                    Text("打开系统设置")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DSTheme.Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var displayItems: [SyncedHealthMetricItem] {
        [
            metric(.birthYear, imageName: "SyncedHealthAgeIcon", fallbackTitle: "年龄", fallbackValue: "36", fallbackUnit: "岁"),
            metric(.sex, imageName: "SyncedHealthSexIcon", fallbackTitle: "性别", fallbackValue: "女", fallbackUnit: ""),
            metric(.heightCm, imageName: "SyncedHealthHeightIcon", fallbackTitle: "身高", fallbackValue: "165", fallbackUnit: "cm"),
            metric(.weightKg, imageName: "SyncedHealthWeightIcon", fallbackTitle: "体重", fallbackValue: "63", fallbackUnit: "kg"),
            metric(.todaySteps, imageName: "SyncedHealthStepsIcon", fallbackTitle: "昨日步数", fallbackValue: "7,820", fallbackUnit: ""),
            metric(.exerciseMinutes, imageName: "SyncedHealthExerciseIcon", fallbackTitle: "运动", fallbackValue: "32", fallbackUnit: "分钟"),
            metric(.restingHeartRate, imageName: "SyncedHealthHeartIcon", fallbackTitle: "静息心率", fallbackValue: "67", fallbackUnit: "bpm"),
            metric(.sleepHours, imageName: "SyncedHealthSleepIcon", fallbackTitle: "睡眠", fallbackValue: "7 小时 24 分", fallbackUnit: "")
        ]
    }

    private func metric(
        _ field: HealthDataField,
        imageName: String,
        fallbackTitle: String,
        fallbackValue: String,
        fallbackUnit: String
    ) -> SyncedHealthMetricItem {
        guard let card = viewModel.cards.first(where: { $0.id == field }),
              card.source != .missing,
              card.value != "--" else {
            return SyncedHealthMetricItem(
                id: field,
                imageName: imageName,
                title: fallbackTitle,
                value: fallbackValue,
                unit: fallbackUnit
            )
        }

        return SyncedHealthMetricItem(
            id: field,
            imageName: imageName,
            title: field == .todaySteps ? "昨日步数" : card.title,
            value: formattedValue(for: field, value: card.value),
            unit: field == .sleepHours ? "" : card.unit
        )
    }

    private func formattedValue(for field: HealthDataField, value: String) -> String {
        guard field == .sleepHours,
              let hours = Double(value.replacingOccurrences(of: ",", with: "")) else {
            return value
        }

        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        return "\(wholeHours) 小时 \(minutes) 分"
    }
}

private struct SyncedHealthMetricItem: Identifiable {
    let id: HealthDataField
    let imageName: String
    let title: String
    let value: String
    let unit: String
}

private struct SyncedHealthMetricTile: View {
    let item: SyncedHealthMetricItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(item.value)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        if !item.unit.isEmpty {
                            Text(item.unit)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DSTheme.Color.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SyncedHealthDataView(onContinue: {})
    }
}
