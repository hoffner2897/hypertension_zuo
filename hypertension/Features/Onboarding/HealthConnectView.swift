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
    @State private var isShowingSyncExplanation = false
    #if DEBUG
    @State private var isShowingSyncedDataTest = false
    #endif

    private let dataTypes = [
        HealthConnectDataType(imageName: "HealthConnectProfileIcon", title: "年龄、性别、身高、体重"),
        HealthConnectDataType(imageName: "HealthConnectActivityIcon", title: "步数与运动记录"),
        HealthConnectDataType(imageName: "HealthConnectHeartIcon", title: "心率与静息心率"),
        HealthConnectDataType(imageName: "HealthConnectSleepIcon", title: "睡眠数据")
    ]

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    heroImage

                    if let errorMessage = viewModel.errorMessage {
                        AuthErrorBanner(message: errorMessage)
                    }

                    dataCard

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.requestAuthorization()
                                if viewModel.errorMessage == nil {
                                    onConnect()
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text("连接 Apple Health")
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(DSTheme.Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isPrimaryActionDisabled)
                        .opacity(viewModel.isPrimaryActionDisabled ? 0.58 : 1)

                        Button {
                            isShowingSyncExplanation = true
                        } label: {
                            Text("查看同步说明")
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

                        #if DEBUG
                        Button {
                            isShowingSyncedDataTest = true
                        } label: {
                            Text("测试已同步基础数据界面")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(DSTheme.Color.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(DSTheme.Color.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                }
                .padding(.horizontal, DSTheme.Spacing.large)
                .padding(.top, DSTheme.Spacing.medium)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("同步说明", isPresented: $isShowingSyncExplanation) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("BPHealth 只读取你授权的 Apple Health 数据，用于理解读数和趋势。连接后可减少重复手动填写，未授权或缺失的数据仍可稍后补充。")
        }
        #if DEBUG
        .sheet(isPresented: $isShowingSyncedDataTest) {
            SyncedHealthDataView(
                onContinue: {
                    isShowingSyncedDataTest = false
                },
                onResync: {}
            )
        }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
            HStack(alignment: .top) {
                Button {
                    onSkip()
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
                Text("连接 Apple Health")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("先连接 Apple Watch 和 Apple Health，\n自动同步基础健康数据。")
                    .font(.subheadline.weight(.medium))
                    .lineSpacing(4)
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
        }
    }

    private var heroImage: some View {
        Image("HealthConnectHero")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: 206)
            .clipped()
            .accessibilityHidden(true)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("将自动同步以下数据")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                .padding(.bottom, 12)

            ForEach(dataTypes) { item in
                HealthConnectDataRow(item: item)

                if item.id != dataTypes.last?.id {
                    Divider()
                        .padding(.leading, 50)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSTheme.Color.primary)

                Text("已连接后，无需重复手动填写。")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
            .padding(.top, 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
}

private struct HealthConnectDataType: Identifiable {
    let imageName: String
    let title: String

    var id: String { imageName }
}

private struct HealthConnectDataRow: View {
    let item: HealthConnectDataType

    var body: some View {
        HStack(spacing: 14) {
            Image(item.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)
        }
        .frame(height: 54)
    }
}

#Preview {
    NavigationStack {
        HealthConnectView(onConnect: {}, onSkip: {})
    }
}
