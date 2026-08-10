//
//  BloodPressureHomeView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI
import SwiftData

struct BloodPressureHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    private let userId: String
    private let preferredMeasurementDate: Date?
    private let onBackToToday: (() -> Void)?
    @StateObject private var viewModel = BloodPressureHomeViewModel()
    @State private var path: [BloodPressureRoute] = []
    @State private var isInterpretationExpanded = false
    @State private var showsAllHistory = false
    @State private var readingPendingDeletion: BloodPressureReading?
    @Query private var savedReadings: [BloodPressureReading]

    init(
        userId: String = "",
        preferredMeasurementDate: Date? = nil,
        onBackToToday: (() -> Void)? = nil
    ) {
        self.userId = userId
        self.preferredMeasurementDate = preferredMeasurementDate
        self.onBackToToday = onBackToToday
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

    private var displayedTrendPoints: [BPTrendDisplayPoint] {
        if trendPoints.isEmpty {
            return BPTrendDisplayPoint.placeholderWeek
        }

        return trendPoints.prefix(7).map { point in
            BPTrendDisplayPoint(
                dayLabel: Self.trendDayFormatter.string(from: point.measuredAt),
                weekdayLabel: Self.trendWeekdayFormatter.string(from: point.measuredAt),
                systolic: point.systolic,
                diastolic: point.diastolic
            )
        }
    }

    private var displayedHistoryReadings: [BloodPressureReading] {
        showsAllHistory ? savedReadings : Array(savedReadings.prefix(5))
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
                    VStack(alignment: .leading, spacing: 14) {
                        readingHeader

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

                        trendCard

                        Button {
                            path.append(.cameraUpload)
                        } label: {
                            HStack(spacing: DSTheme.Spacing.small) {
                                Image("BPReadingCameraIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                                Text("拍照上传读数")
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(DSTheme.Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showsAllHistory.toggle()
                            }
                        } label: {
                            Text("查看历史读数")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(DSTheme.Color.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
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
                            path.append(.confirmReading(draftWithPreferredMeasurementDate(Self.confirmReadingTestDraft)))
                        } label: {
                            HStack(spacing: DSTheme.Spacing.small) {
                                Image(systemName: "testtube.2")
                                    .font(.headline.weight(.bold))

                                Text("测试确认读数界面")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(DSTheme.Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(DSTheme.Color.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        #endif

                        if showsAllHistory, !savedReadings.isEmpty {
                            historyCard
                        }

                        if let historyActionErrorMessage = viewModel.historyActionErrorMessage {
                            DSCard {
                                HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(DSTheme.Color.warning)

                                    Text(historyActionErrorMessage)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(DSTheme.Color.warning)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                    }
                    .padding(.horizontal, DSTheme.Spacing.large)
                    .padding(.top, DSTheme.Spacing.medium)
                    .padding(.bottom, 104)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BloodPressureRoute.self) { route in
                switch route {
                case .cameraUpload:
                    BPCameraUploadMockView(
                        onRecognized: { draft in
                            path.append(.confirmReading(draftWithPreferredMeasurementDate(draft)))
                        },
                        onManualInput: { draft in
                            path.append(.confirmReading(draftWithPreferredMeasurementDate(draft)))
                        }
                    )
                case .confirmReading(let draft):
                    BPConfirmReadingView(draft: draft, userId: userId) { _ in
                        path.removeAll()
                        refreshAfterLocalChange()
                    }
                case .editReading(let readingId):
                    if let reading = savedReadings.first(where: { $0.id == readingId }) {
                        BPConfirmReadingView(
                            draft: BPReadingDraft(reading: reading),
                            userId: userId,
                            existingReading: reading
                        ) { _ in
                            path.removeAll()
                            refreshAfterLocalChange()
                        }
                    } else {
                        ContentUnavailableView("找不到这条读数", systemImage: "heart.slash")
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
            .alert(
                "删除这条读数？",
                isPresented: Binding(
                    get: { readingPendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented {
                            readingPendingDeletion = nil
                        }
                    }
                ),
                presenting: readingPendingDeletion
            ) { reading in
                Button("删除", role: .destructive) {
                    Task {
                        _ = await viewModel.deleteReading(
                            reading,
                            userId: userId,
                            repository: SwiftDataBloodPressureReadingRepository(modelContext: modelContext)
                        )
                        readingPendingDeletion = nil
                    }
                }

                Button("取消", role: .cancel) {
                    readingPendingDeletion = nil
                }
            } message: { reading in
                Text("将删除 \(reading.systolic)/\(reading.diastolic) mmHg（\(Self.historyDateFormatter.string(from: reading.measuredAt))）。此操作不能撤销。")
            }
        }
    }

    private var readingHeader: some View {
        VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
            HStack(alignment: .top) {
                Button {
                    if let onBackToToday {
                        onBackToToday()
                    } else {
                        dismiss()
                    }
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
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("读数卡片")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                Text("通过拍照上传今天的血压计读数。")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
        }
    }

    @ViewBuilder
    private var recentMeasurementCard: some View {
        DSCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("最近的读数")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                HStack(spacing: 16) {
                    Image("BPReadingMonitorHero")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 150)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 10) {
                        if let reading = latestReading {
                            Text("\(reading.systolic) / \(reading.diastolic)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text("mmHg")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DSTheme.Color.textSecondary)

                            if let pulse = reading.pulse {
                                Text("脉搏 \(pulse) bpm")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.textSecondary)
                            }
                        } else {
                            Text("还没有读数")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                                .fixedSize(horizontal: false, vertical: true)

                            Text("拍照上传血压计屏幕，系统会自动识别并分析。")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(.cameraUpload)
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
        DSCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("最近 7 天趋势")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                        Text("每日取当日血压测量的平均值，呈现趋势分析")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DSTheme.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        TrendLegendItem(title: "收缩压 (mmHg)", imageName: "BPReadingChartSystolicGlyph")
                        TrendLegendItem(title: "舒张压 (mmHg)", imageName: "BPReadingChartDiastolicGlyph")
                    }
                }

                BPTrendChart(points: displayedTrendPoints)
                    .frame(height: 210)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption.weight(.bold))

                    Text(trendPoints.isEmpty ? "上传后可查看趋势变化" : "趋势用于观察变化，不用于诊断。")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(red: 0.37, green: 0.50, blue: 0.74))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color(red: 0.93, green: 0.96, blue: 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private var historyCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
                        Text("历史读数")
                            .font(.headline)
                            .foregroundStyle(DSTheme.Color.textPrimary)

                        Text("共 \(savedReadings.count) 条，按测量时间排列")
                            .font(.caption)
                            .foregroundStyle(DSTheme.Color.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.primary)
                }

                ForEach(displayedHistoryReadings) { reading in
                    historyRow(reading)

                    if reading.id != displayedHistoryReadings.last?.id {
                        Divider()
                    }
                }

                if savedReadings.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsAllHistory.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showsAllHistory ? "收起" : "查看全部 \(savedReadings.count) 条")
                            Image(systemName: showsAllHistory ? "chevron.up" : "chevron.down")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DSTheme.Color.primary)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func historyRow(_ reading: BloodPressureReading) -> some View {
        HStack(spacing: DSTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: DSTheme.Spacing.xSmall) {
                Text("\(reading.systolic)/\(reading.diastolic) mmHg")
                    .font(.headline)
                    .foregroundStyle(DSTheme.Color.textPrimary)

                HStack(spacing: DSTheme.Spacing.small) {
                    Text(Self.historyDateFormatter.string(from: reading.measuredAt))

                    if let pulse = reading.pulse {
                        Text("脉搏 \(pulse)")
                    }

                    Text(BPReadingSource.fromStoredValue(reading.source).label)
                }
                .font(.caption)
                .foregroundStyle(DSTheme.Color.textSecondary)
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    viewModel.clearHistoryActionError()
                    path.append(.editReading(reading.id))
                } label: {
                    Label("编辑", systemImage: "square.and.pencil")
                }

                Button(role: .destructive) {
                    viewModel.clearHistoryActionError()
                    readingPendingDeletion = reading
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(DSTheme.Color.primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.isUpdatingHistory)
            .accessibilityLabel("管理 \(reading.systolic)/\(reading.diastolic) 读数")
        }
        .contentShape(Rectangle())
    }

    private func refreshAfterLocalChange() {
        Task {
            await viewModel.syncPendingReadings(userId: userId)
            await viewModel.refreshRemoteReadings(
                userId: userId,
                repository: SwiftDataBloodPressureReadingRepository(modelContext: modelContext)
            )
        }
    }

    private func draftWithPreferredMeasurementDate(_ draft: BPReadingDraft) -> BPReadingDraft {
        guard let preferredMeasurementDate else {
            return draft
        }

        var updatedDraft = draft
        updatedDraft.measuredAt = preferredMeasurementDate
        return updatedDraft
    }

    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMd HH:mm")
        return formatter
    }()

    private static let trendDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static let trendWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    #if DEBUG
    private static var confirmReadingTestDraft: BPReadingDraft {
        BPReadingDraft(
            source: .cameraRecognition,
            systolic: "128",
            diastolic: "82",
            pulse: "72",
            measuredAt: Date()
        )
    }
    #endif
}

private enum BloodPressureRoute: Hashable {
    case cameraUpload
    case confirmReading(BPReadingDraft)
    case editReading(UUID)
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
    let imageName: String

    var body: some View {
        HStack(spacing: 4) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 16, height: 8)
                .clipped()

            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)
                .lineLimit(1)
        }
    }
}

private struct BPTrendDisplayPoint: Identifiable, Hashable {
    let id = UUID()
    let dayLabel: String
    let weekdayLabel: String
    let systolic: Int?
    let diastolic: Int?

    static let placeholderWeek: [BPTrendDisplayPoint] = [
        BPTrendDisplayPoint(dayLabel: "6/3", weekdayLabel: "周二", systolic: 126, diastolic: 82),
        BPTrendDisplayPoint(dayLabel: "6/4", weekdayLabel: "周三", systolic: 124, diastolic: 80),
        BPTrendDisplayPoint(dayLabel: "6/5", weekdayLabel: "周四", systolic: 128, diastolic: 84),
        BPTrendDisplayPoint(dayLabel: "6/6", weekdayLabel: "周五", systolic: 122, diastolic: 78),
        BPTrendDisplayPoint(dayLabel: "6/7", weekdayLabel: "周六", systolic: 130, diastolic: 85),
        BPTrendDisplayPoint(dayLabel: "6/8", weekdayLabel: "周日", systolic: 125, diastolic: 81),
        BPTrendDisplayPoint(dayLabel: "6/9", weekdayLabel: "周一\n(今天)", systolic: nil, diastolic: nil)
    ]
}

private struct BPTrendChart: View {
    let points: [BPTrendDisplayPoint]

    private let minValue = 40
    private let maxValue = 160
    private let yAxisMarks = [160, 140, 120, 100, 80, 60, 40]

    private var systolicColor: Color {
        Color(red: 0.06, green: 0.32, blue: 1.0)
    }

    private var diastolicColor: Color {
        Color(red: 1.0, green: 0.14, blue: 0.42)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 7) {
                VStack {
                    ForEach(yAxisMarks, id: \.self) { mark in
                        Text("\(mark)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(red: 0.40, green: 0.48, blue: 0.62))
                            .frame(maxHeight: .infinity, alignment: mark == yAxisMarks.first ? .top : mark == yAxisMarks.last ? .bottom : .center)
                    }
                }
                .frame(width: 26, height: 148)

                GeometryReader { proxy in
                    ZStack {
                        gridLines(in: proxy.size)

                        trendPath(values: points.map(\.systolic), in: proxy.size)
                            .stroke(systolicColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                        trendPath(values: points.map(\.diastolic), in: proxy.size)
                            .stroke(diastolicColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                        pointMarkers(values: points.map(\.systolic), color: systolicColor, size: proxy.size)
                        pointMarkers(values: points.map(\.diastolic), color: diastolicColor, size: proxy.size)
                        valueLabels(values: points.map(\.systolic), color: systolicColor, yOffset: -14, size: proxy.size)
                        valueLabels(values: points.map(\.diastolic), color: diastolicColor, yOffset: 14, size: proxy.size)
                        missingValueMarkers(size: proxy.size)
                    }
                }
                .frame(height: 148)
            }

            HStack(spacing: 0) {
                ForEach(points) { point in
                    Text("\(point.dayLabel)\n\(point.weekdayLabel)")
                        .font(.system(size: 9, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.40, green: 0.48, blue: 0.62))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, 33)
        }
    }

    private func gridLines(in size: CGSize) -> some View {
        ZStack {
            ForEach(yAxisMarks, id: \.self) { mark in
                Rectangle()
                    .fill(DSTheme.Color.border.opacity(0.75))
                    .frame(height: 1)
                    .position(x: size.width / 2, y: chartY(for: mark, in: size))
            }
        }
    }

    private func trendPath(values: [Int?], in size: CGSize) -> Path {
        Path { path in
            var didMove = false

            for index in values.indices {
                guard let value = values[index] else {
                    continue
                }

                let point = chartPoint(for: value, index: index, count: values.count, size: size)

                if !didMove {
                    path.move(to: point)
                    didMove = true
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func pointMarkers(values: [Int?], color: Color, size: CGSize) -> some View {
        ZStack {
            ForEach(values.indices, id: \.self) { index in
                if let value = values[index] {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(chartPoint(for: value, index: index, count: values.count, size: size))
                }
            }
        }
    }

    private func valueLabels(values: [Int?], color: Color, yOffset: CGFloat, size: CGSize) -> some View {
        ZStack {
            ForEach(values.indices, id: \.self) { index in
                if let value = values[index] {
                    Text("\(value)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(color)
                        .position(
                            x: chartPoint(for: value, index: index, count: values.count, size: size).x,
                            y: chartPoint(for: value, index: index, count: values.count, size: size).y + yOffset
                        )
                }
            }
        }
    }

    private func missingValueMarkers(size: CGSize) -> some View {
        ZStack {
            ForEach(points.indices, id: \.self) { index in
                if points[index].systolic == nil && points[index].diastolic == nil {
                    Text("--")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(systolicColor)
                        .position(x: chartX(for: index, count: points.count, size: size), y: chartY(for: 125, in: size))

                    Text("--")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(diastolicColor)
                        .position(x: chartX(for: index, count: points.count, size: size), y: chartY(for: 82, in: size))
                }
            }
        }
    }

    private func chartPoint(for value: Int, index: Int, count: Int, size: CGSize) -> CGPoint {
        CGPoint(x: chartX(for: index, count: count, size: size), y: chartY(for: value, in: size))
    }

    private func chartX(for index: Int, count: Int, size: CGSize) -> CGFloat {
        let horizontalInset: CGFloat = 12
        let usableWidth = max(size.width - horizontalInset * 2, 1)
        let xStep = count > 1 ? usableWidth / CGFloat(count - 1) : 0
        return horizontalInset + CGFloat(index) * xStep
    }

    private func chartY(for value: Int, in size: CGSize) -> CGFloat {
        let verticalInset: CGFloat = 8
        let usableHeight = max(size.height - verticalInset * 2, 1)
        let valueRange = max(maxValue - minValue, 1)
        let normalized = CGFloat(value - minValue) / CGFloat(valueRange)
        return verticalInset + (1 - normalized) * usableHeight
    }
}

#Preview {
    BloodPressureHomeView()
        .modelContainer(for: BloodPressureReading.self, inMemory: true)
}
