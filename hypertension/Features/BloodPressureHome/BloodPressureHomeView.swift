//
//  BloodPressureHomeView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI
import SwiftData

struct BloodPressureHomeView: View {
    @Environment(\.modelContext) private var modelContext
    private let userId: String
    @StateObject private var viewModel = BloodPressureHomeViewModel()
    @State private var path: [BloodPressureRoute] = []
    @State private var isInterpretationExpanded = false
    @Query private var savedReadings: [BloodPressureReading]

    init(userId: String = "") {
        self.userId = userId
        _savedReadings = Query(
            filter: #Predicate<BloodPressureReading> { reading in
                reading.userId == userId
            },
            sort: \.measuredAt,
            order: .reverse
        )
    }

    private var latestReading: BloodPressureReading? {
        savedReadings.first
    }

    private var trendPoints: [BloodPressureTrendPoint] {
        viewModel.trendPoints(from: savedReadings)
    }

    private var interpretationRefreshKey: String {
        guard let reading = latestReading else {
            return "none"
        }

        return "\(reading.id.uuidString)-\(reading.systolic)-\(reading.diastolic)-\(reading.pulse ?? 0)-\(savedReadings.count)"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DSTheme.Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        DSSectionHeader(
                            "读数卡片",
                            subtitle: "查看最近测量和近期趋势。",
                            systemImage: "heart.text.square"
                        )

                        recentMeasurementCard
                        interpretationCard

                        if let syncStatusMessage = viewModel.syncStatusMessage {
                            DSCard {
                                HStack(spacing: DSTheme.Spacing.small) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(DSTheme.Color.primary)

                                    Text(syncStatusMessage)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(DSTheme.Color.textSecondary)
                                }
                            }
                        }

                        if trendPoints.isEmpty {
                            emptyTrendCard
                        } else {
                            trendCard
                        }

                    }
                    .padding(DSTheme.Spacing.large)
                }
            }
            .navigationTitle("Blood Pressure")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BloodPressureRoute.self) { route in
                switch route {
                case .cameraUpload:
                    BPCameraUploadMockView(
                        onRecognized: { draft in
                            path.append(.confirmReading(draft))
                        },
                        onManualInput: { draft in
                            path.append(.confirmReading(draft))
                        }
                    )
                case .confirmReading(let draft):
                    BPConfirmReadingView(draft: draft, userId: userId) { _ in
                        path.removeAll()
                        Task {
                            await viewModel.syncPendingReadings(userId: userId)
                            await viewModel.refreshRemoteReadings(
                                userId: userId,
                                repository: SwiftDataBloodPressureReadingRepository(modelContext: modelContext)
                            )
                        }
                    }
                }
            }
            .task {
                await viewModel.syncPendingReadings(userId: userId)
                await viewModel.refreshRemoteReadings(
                    userId: userId,
                    repository: SwiftDataBloodPressureReadingRepository(modelContext: modelContext)
                )
            }
            .task(id: interpretationRefreshKey) {
                await viewModel.refreshInterpretation(
                    reading: latestReading,
                    recentReadings: Array(savedReadings.prefix(20))
                )
            }
        }
    }

    @ViewBuilder
    private var recentMeasurementCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                HStack(alignment: .top, spacing: DSTheme.Spacing.medium) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .frame(width: 44, height: 44)
                        .background(DSTheme.Color.primarySoft)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
                        Text("最近测量")
                            .font(.headline)
                            .foregroundStyle(DSTheme.Color.textPrimary)

                        if let reading = latestReading {
                            Text("\(reading.systolic)/\(reading.diastolic) mmHg")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(DSTheme.Color.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            if let pulse = reading.pulse {
                                Text("脉搏 \(pulse) bpm")
                                    .font(.subheadline)
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }

                            Text(Self.relativeMeasurementText(for: reading.measuredAt))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DSTheme.Color.textSecondary)
                        } else {
                            Text("还未记录读数")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(DSTheme.Color.textPrimary)

                            Text("添加你的第一次血压读数")
                                .font(.subheadline)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                        }
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: DSTheme.Spacing.small) {
                        BPQuickActionButton(systemImage: "camera.fill", accessibilityLabel: "拍照上传读数") {
                            path.append(.cameraUpload)
                        }

                        BPQuickActionButton(systemImage: "square.and.pencil", accessibilityLabel: "手动添加读数") {
                            path.append(.confirmReading(viewModel.emptyDraft))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var interpretationCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isInterpretationExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: DSTheme.Spacing.medium) {
                    Image(systemName: interpretationIcon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(interpretationTint)
                        .frame(width: 44, height: 44)
                        .background(interpretationTint.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
                        Text("最近血压解释")
                            .font(.headline)
                            .foregroundStyle(DSTheme.Color.textPrimary)

                        if latestReading == nil {
                            Text("保存血压读数后，这里会解释正常与否和原因。")
                                .font(.subheadline)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if viewModel.isLoadingInterpretation && viewModel.interpretation == nil {
                            HStack(spacing: DSTheme.Spacing.small) {
                                ProgressView()
                                    .controlSize(.small)

                                Text("正在生成解释")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }
                        } else if let interpretation = viewModel.interpretation {
                            DSChip(interpretation.severity.displayTitle, systemImage: interpretationIcon, tint: interpretationTint, isSelected: true)

                            Text(interpretation.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(DSTheme.Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(interpretation.summary)
                                .font(.subheadline)
                                .foregroundStyle(DSTheme.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isInterpretationExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .padding(.top, 4)
                    }
                }
                .buttonStyle(.plain)

                if let message = viewModel.interpretationErrorMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isInterpretationExpanded, let interpretation = viewModel.interpretation {
                    interpretationBullets(title: "原因", items: interpretation.reasons, icon: "list.bullet.clipboard")

                    if !interpretation.personalContextNotes.isEmpty {
                        interpretationBullets(title: "个人背景", items: interpretation.personalContextNotes, icon: "person.text.rectangle")
                    }

                    interpretationBullets(title: "测量提示", items: interpretation.measurementQualityNotes, icon: "checkmark.shield")
                    interpretationBullets(title: "下一步", items: interpretation.nextSteps, icon: "arrow.right.circle")

                    Text(interpretation.safetyNote)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(interpretation.severity == .urgent ? DSTheme.Color.warning : DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(interpretation.disclaimer)
                        .font(.caption)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private static func relativeMeasurementText(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "今天 \(Self.measurementTimeFormatter.string(from: date))"
        }

        return Self.measurementDateFormatter.string(from: date)
    }

    private static let measurementTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let measurementDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.setLocalizedDateFormatFromTemplate("MMMd HH:mm")
        return formatter
    }()

    private func interpretationBullets(title: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.small) {
            HStack(spacing: DSTheme.Spacing.xSmall) {
                Image(systemName: icon)
                    .foregroundStyle(DSTheme.Color.primary)

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DSTheme.Color.textPrimary)
            }

            ForEach(items.prefix(3), id: \.self) { item in
                HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
                    Circle()
                        .fill(interpretationTint)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)

                    Text(item)
                        .font(.footnote)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var interpretationTint: Color {
        switch viewModel.interpretation?.severity {
        case .urgent:
            return DSTheme.Color.warning
        case .followUp, .repeat:
            return DSTheme.Color.warning
        case .watch:
            return DSTheme.Color.primary
        case .reassuring:
            return DSTheme.Color.success
        case nil:
            return DSTheme.Color.primary
        }
    }

    private var interpretationIcon: String {
        switch viewModel.interpretation?.severity {
        case .urgent:
            return "exclamationmark.triangle.fill"
        case .followUp, .repeat:
            return "arrow.clockwise.heart"
        case .watch:
            return "eye.fill"
        case .reassuring:
            return "checkmark.seal.fill"
        case nil:
            return "heart.text.square"
        }
    }

    private var trendCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                HStack {
                    Text("\(trendPoints.count) 天趋势")
                        .font(.headline)
                        .foregroundStyle(DSTheme.Color.textPrimary)

                    Spacer()

                    HStack(spacing: DSTheme.Spacing.small) {
                        TrendLegendItem(title: "收缩压", color: DSTheme.Color.primary)
                        TrendLegendItem(title: "舒张压", color: DSTheme.Color.success)
                    }
                }

                BPTrendChart(points: trendPoints)
                    .frame(height: 190)
            }
        }
    }

    private var emptyTrendCard: some View {
        DSCard {
            HStack(alignment: .top, spacing: DSTheme.Spacing.medium) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(width: 44, height: 44)
                    .background(DSTheme.Color.primarySoft)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
                    Text("还没有趋势")
                        .font(.headline)
                        .foregroundStyle(DSTheme.Color.textPrimary)

                    Text("保存一次血压读数后，这里会显示已有天数的趋势。")
                        .font(.subheadline)
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private enum BloodPressureRoute: Hashable {
    case cameraUpload
    case confirmReading(BPReadingDraft)
}

private struct BPQuickActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DSTheme.Color.primary)
                .frame(width: 42, height: 42)
                .background(DSTheme.Color.primarySoft)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private extension BPInterpretationSeverity {
    var displayTitle: String {
        switch self {
        case .reassuring:
            return "稳定"
        case .watch:
            return "观察"
        case .repeat:
            return "建议复测"
        case .followUp:
            return "建议随访"
        case .urgent:
            return "需要重视"
        }
    }
}

private struct TrendLegendItem: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)
                .lineLimit(1)
        }
    }
}

private struct BPTrendChart: View {
    let points: [BloodPressureTrendPoint]

    private var allValues: [Int] {
        points.flatMap { [$0.systolic, $0.diastolic] }
    }

    private var minValue: Int {
        max((allValues.min() ?? 70) - 8, 0)
    }

    private var maxValue: Int {
        (allValues.max() ?? 130) + 8
    }

    var body: some View {
        VStack(spacing: DSTheme.Spacing.small) {
            GeometryReader { proxy in
                ZStack {
                    gridLines

                    trendPath(values: points.map(\.systolic), in: proxy.size)
                        .stroke(DSTheme.Color.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    trendPath(values: points.map(\.diastolic), in: proxy.size)
                        .stroke(DSTheme.Color.success, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    pointMarkers(values: points.map(\.systolic), color: DSTheme.Color.primary, size: proxy.size)
                    pointMarkers(values: points.map(\.diastolic), color: DSTheme.Color.success, size: proxy.size)
                }
            }

            HStack {
                ForEach(points) { point in
                    Text(point.day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var gridLines: some View {
        VStack {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(DSTheme.Color.border)
                    .frame(height: 1)

                Spacer()
            }
        }
    }

    private func trendPath(values: [Int], in size: CGSize) -> Path {
        Path { path in
            guard values.count > 1 else { return }

            for index in values.indices {
                let point = chartPoint(for: values[index], index: index, count: values.count, size: size)

                if index == values.startIndex {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func pointMarkers(values: [Int], color: Color, size: CGSize) -> some View {
        ZStack {
            ForEach(values.indices, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .position(chartPoint(for: values[index], index: index, count: values.count, size: size))
            }
        }
    }

    private func chartPoint(for value: Int, index: Int, count: Int, size: CGSize) -> CGPoint {
        let horizontalInset: CGFloat = 10
        let verticalInset: CGFloat = 12
        let usableWidth = max(size.width - horizontalInset * 2, 1)
        let usableHeight = max(size.height - verticalInset * 2, 1)
        let xStep = count > 1 ? usableWidth / CGFloat(count - 1) : 0
        let valueRange = max(maxValue - minValue, 1)
        let normalized = CGFloat(value - minValue) / CGFloat(valueRange)
        let x = horizontalInset + CGFloat(index) * xStep
        let y = verticalInset + (1 - normalized) * usableHeight

        return CGPoint(x: x, y: y)
    }
}

#Preview {
    BloodPressureHomeView()
        .modelContainer(for: BloodPressureReading.self, inMemory: true)
}
