//
//  BPReadingAnalysisView.swift
//  hypertension
//
//  Created by Codex on 2026/7/22.
//

import SwiftUI

struct BPReadingAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    let draft: BPReadingDraft

    private var systolicText: String {
        draft.systolic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "128" : draft.systolic
    }

    private var diastolicText: String {
        draft.diastolic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "82" : draft.diastolic
    }

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    currentReadingCard
                    contextMetrics
                    analyzingBlock
                }
                .padding(.horizontal, DSTheme.Spacing.large)
                .padding(.top, DSTheme.Spacing.medium)
                .padding(.bottom, 112)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
                    Image(exercisePresentationSex.avatarAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))

                    Text(L10n.string("小宁"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("正在理解你的读数"))
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(L10n.string("结合 Apple Watch 数据进行分析。"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
        }
    }

    private var currentReadingCard: some View {
        HStack(spacing: 18) {
            Image("BPAnalysisHeartHero")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("当前血压"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(systolicText) / \(diastolicText)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(L10n.string("mmHg"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.26, green: 0.34, blue: 0.58))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 10)
    }

    private var contextMetrics: some View {
        HStack(spacing: 10) {
            BPAnalysisMetricCard(imageName: "BPAnalysisSleepIcon", title: "昨夜睡眠", value: "7", suffix: "小时 24 分")
            BPAnalysisMetricCard(imageName: "BPAnalysisStepsIcon", title: "昨日步数", value: "7,820", suffix: "")
            BPAnalysisMetricCard(imageName: "BPAnalysisExerciseIcon", title: "运动", value: "32", suffix: "分钟")
            BPAnalysisMetricCard(imageName: "BPAnalysisRestingHeartIcon", title: "静息心率", value: "67", suffix: "bpm")
        }
    }

    private var analyzingBlock: some View {
        VStack(spacing: 28) {
            Image("BPAnalysisSpinner")
                .resizable()
                .scaledToFit()
                .frame(width: 94, height: 94)
                .accessibilityLabel(L10n.string("分析中"))

            Text(L10n.string("我们正在结合近期趋势与日常状态。"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                .multilineTextAlignment(.center)

            Text(L10n.string("分析中..."))
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.52, green: 0.66, blue: 0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(red: 0.89, green: 0.93, blue: 1.0))
                .clipShape(Capsule())

            #if DEBUG
            NavigationLink {
                BPReadingNormalView(draft: draft)
            } label: {
                HStack(spacing: DSTheme.Spacing.small) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.headline.weight(.bold))

                    Text(L10n.string("测试读数正常界面"))
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(DSTheme.Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(DSTheme.Color.primarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

            NavigationLink {
                BPReadingHighView(draft: Self.highReadingTestDraft)
            } label: {
                HStack(spacing: DSTheme.Spacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.headline.weight(.bold))

                    Text(L10n.string("测试读数偏高界面"))
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.07))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(red: 1.0, green: 0.92, blue: 0.86))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    #if DEBUG
    private static var highReadingTestDraft: BPReadingDraft {
        BPReadingDraft(
            source: .cameraRecognition,
            systolic: "145",
            diastolic: "95",
            pulse: "88",
            measuredAt: Date()
        )
    }
    #endif
}

private struct BPAnalysisMetricCard: View {
    let imageName: String
    let title: String
    let value: String
    let suffix: String

    var body: some View {
        VStack(spacing: 8) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            Text(L10n.string(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if !suffix.isEmpty {
                    Text(L10n.string(suffix))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .frame(height: 146)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 7)
    }
}

#Preview {
    NavigationStack {
        BPReadingAnalysisView(
            draft: BPReadingDraft(
                source: .cameraRecognition,
                systolic: "128",
                diastolic: "82",
                pulse: "72",
                measuredAt: Date()
            )
        )
    }
}
