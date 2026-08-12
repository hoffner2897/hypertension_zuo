//
//  BPReadingHighView.swift
//  hypertension
//
//  Created by Codex on 2026/7/22.
//

import SwiftUI

struct BPReadingHighView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.exercisePresentationSex) private var exercisePresentationSex
    let draft: BPReadingDraft

    private var systolicText: String {
        draft.systolic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "145" : draft.systolic
    }

    private var diastolicText: String {
        draft.diastolic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "95" : draft.diastolic
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
                            imageName: "BPHighWarningIcon",
                            title: "为什么这是偏高的",
                            body: "你的收缩压（\(systolicText)）和舒张压（\(diastolicText)）均高于正常范围，说明你的血压目前处于偏高水平，需要引起重视。"
                        )
                        resultInfoCard(
                            imageName: "BPHighLeafIcon",
                            title: "你的习惯可能在影响血压",
                            body: "压力、睡眠不足、饮食过咸、缺乏运动、饮酒等因素都可能导致血压升高。积极调整生活方式有助于改善血压水平。"
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
                Text("你的读数偏高")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                Text("你的血压高于健康范围，需要关注。\n请注意休息并保持良好习惯。")
                    .font(.subheadline.weight(.medium))
                    .lineSpacing(4)
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
        }
    }

    private var readingCard: some View {
        ZStack(alignment: .bottom) {
            HStack {
                HighResultLeafDecoration()
                    .frame(width: 72, height: 112)
                    .opacity(0.78)

                Spacer()

                HighResultLeafDecoration()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: 72, height: 112)
                    .opacity(0.78)
            }
            .padding(.horizontal, -8)
            .padding(.bottom, -1)

            VStack(spacing: 14) {
                Text("今日最新血压")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.12, blue: 0.18))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(Color(red: 1.0, green: 0.88, blue: 0.89))
                    .clipShape(Capsule())

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(systolicText)
                        .foregroundStyle(Color(red: 1.0, green: 0.15, blue: 0.16))

                    Text("/")
                        .foregroundStyle(Color(red: 0.48, green: 0.54, blue: 0.74))

                    Text(diastolicText)
                        .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.07))

                    Text("mmHg")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.26, green: 0.34, blue: 0.58))
                }
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text("偏高")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.15, blue: 0.16))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                    .background(Color(red: 1.0, green: 0.9, blue: 0.9))
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
                    Text("休息后再次测量")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                    Text("安静休息 5 分钟后再测量。\n如持续偏高，请咨询医生并保持定期监测。")
                        .font(.caption.weight(.medium))
                        .lineSpacing(3)
                        .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                        .fixedSize(horizontal: false, vertical: true)
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

private struct HighResultLeafDecoration: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.62).opacity(0.34))
                    .frame(width: 18, height: 46)
                    .rotationEffect(.degrees(-34 + Double(index) * 13))
                    .offset(x: CGFloat(index) * 9, y: CGFloat(index) * -10)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BPReadingHighView(
            draft: BPReadingDraft(
                source: .cameraRecognition,
                systolic: "145",
                diastolic: "95",
                pulse: "88",
                measuredAt: Date()
            )
        )
    }
}
