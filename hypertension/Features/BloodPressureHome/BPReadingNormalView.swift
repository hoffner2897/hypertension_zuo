//
//  BPReadingNormalView.swift
//  hypertension
//
//  Created by Codex on 2026/7/22.
//

import SwiftUI

struct BPReadingNormalView: View {
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

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        readingCard
                        resultInfoCard(
                            imageName: "BPResultShieldIcon",
                            title: "为什么这是正常的",
                            body: "你的收缩压（\(systolicText)）和舒张压（\(diastolicText)）都在正常范围内，这表明你的血压目前处于健康水平。"
                        )
                        resultInfoCard(
                            imageName: "BPResultLeafIcon",
                            title: "你的习惯正在产生影响",
                            body: "坚持轻运动、均衡饮食、放松呼吸和睡好觉，这些好习惯正在帮助你维持健康的血压。"
                        )
                        continueCard
                    }
                    .padding(.horizontal, DSTheme.Spacing.large)
                    .padding(.top, DSTheme.Spacing.medium)
                    .padding(.bottom, DSTheme.Spacing.large)
                }

                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(DSTheme.Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DSTheme.Spacing.large)
                .padding(.top, 10)
                .padding(.bottom, 28)
                .background(.ultraThinMaterial.opacity(0.65))
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

                    Text("小宁")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("你的读数正常")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                Text("你的血压处于健康范围内。\n你正在好好照顾自己。")
                    .font(.subheadline.weight(.medium))
                    .lineSpacing(4)
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
        }
    }

    private var readingCard: some View {
        ZStack(alignment: .bottom) {
            HStack {
                ResultLeafDecoration()
                    .frame(width: 72, height: 112)
                    .opacity(0.65)

                Spacer()

                ResultLeafDecoration()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: 72, height: 112)
                    .opacity(0.65)
            }
            .padding(.horizontal, -8)
            .padding(.bottom, -1)

            VStack(spacing: 14) {
                Text("今日最新血压")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.07, green: 0.65, blue: 0.28))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.82, green: 0.96, blue: 0.86))
                    .clipShape(Capsule())

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(systolicText)
                        .foregroundStyle(Color(red: 0.07, green: 0.75, blue: 0.34))

                    Text("/")
                        .foregroundStyle(Color(red: 0.48, green: 0.54, blue: 0.74))

                    Text(diastolicText)
                        .foregroundStyle(Color(red: 0.08, green: 0.39, blue: 1.0))

                    Text("mmHg")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.26, green: 0.34, blue: 0.58))
                }
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text("正常")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.07, green: 0.65, blue: 0.28))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.86, green: 0.97, blue: 0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .frame(maxWidth: 312)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func resultInfoCard(imageName: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                Text(body)
                    .font(.subheadline.weight(.medium))
                    .lineSpacing(4)
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 7)
    }

    private var continueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("继续做什么")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("保持规律测量")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                    Text("尽量在固定时间测量，方便看变化。")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color(red: 0.95, green: 0.97, blue: 1.0))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(DSTheme.Color.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 7)
    }
}

private struct ResultLeafDecoration: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color(red: 0.65, green: 0.78, blue: 1.0).opacity(0.5))
                    .frame(width: 18, height: 46)
                    .rotationEffect(.degrees(-34 + Double(index) * 13))
                    .offset(x: CGFloat(index) * 9, y: CGFloat(index) * -10)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BPReadingNormalView(
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
