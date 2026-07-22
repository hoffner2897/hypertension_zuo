//
//  BPConfirmReadingView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import Combine
import SwiftUI
import SwiftData

struct BPConfirmReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: BPConfirmReadingViewModel
    private let userId: String
    private let repository: (any BloodPressureReadingRepository)?
    private let existingReading: BloodPressureReading?
    let onSaveSuccess: (BPReadingDraft) -> Void

    init(
        draft: BPReadingDraft,
        userId: String = "",
        repository: (any BloodPressureReadingRepository)? = nil,
        existingReading: BloodPressureReading? = nil,
        onSaveSuccess: @escaping (BPReadingDraft) -> Void = { _ in }
    ) {
        self._viewModel = StateObject(wrappedValue: BPConfirmReadingViewModel(draft: draft))
        self.userId = userId
        self.repository = repository
        self.existingReading = existingReading
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        ZStack {
            DSTheme.Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                        confirmHeader
                        readingValuesCard

                        #if DEBUG
                        NavigationLink {
                            BPReadingAnalysisView(draft: viewModel.draft)
                        } label: {
                            HStack(spacing: DSTheme.Spacing.small) {
                                Image(systemName: "waveform.path.ecg.rectangle")
                                    .font(.headline.weight(.bold))

                                Text("测试血压读数分析界面")
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

                        if let errorMessage = viewModel.errorMessage {
                            HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(DSTheme.Color.warning)

                                Text(errorMessage)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DSTheme.Color.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, DSTheme.Spacing.small)
                        }
                    }
                    .padding(.horizontal, DSTheme.Spacing.large)
                    .padding(.top, DSTheme.Spacing.medium)
                    .padding(.bottom, DSTheme.Spacing.large)
                }

                Button {
                    saveReading()
                } label: {
                    HStack(spacing: DSTheme.Spacing.small) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(existingReading == nil ? "保存读数" : "更新读数")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(DSTheme.Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
                .padding(.horizontal, DSTheme.Spacing.large)
                .padding(.top, 10)
                .padding(.bottom, 28)
                .background(.ultraThinMaterial.opacity(0.65))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var confirmHeader: some View {
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
                Text(existingReading == nil ? "确认读数" : "编辑读数")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

                Text(existingReading == nil ? "确认数值，并补充本次测量时的状态。" : "修改后会更新历史记录，并在联网时同步。")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.17, green: 0.25, blue: 0.48))
            }
        }
    }

    private var readingValuesCard: some View {
        VStack(spacing: 0) {
            BPConfirmNumberRow(
                imageName: "BPConfirmSystolicIcon",
                title: "收缩压",
                text: $viewModel.draft.systolic,
                unit: "mmHg",
                placeholder: "128"
            )

            BPConfirmDivider()

            BPConfirmNumberRow(
                imageName: "BPConfirmDiastolicIcon",
                title: "舒张压",
                text: $viewModel.draft.diastolic,
                unit: "mmHg",
                placeholder: "82"
            )

            BPConfirmDivider()

            BPConfirmNumberRow(
                imageName: "BPConfirmPulseIcon",
                title: "心率",
                text: $viewModel.draft.pulse,
                unit: "bpm",
                placeholder: "72"
            )

            BPConfirmDivider()

            BPConfirmTimeRow(date: $viewModel.draft.measuredAt)
        }
        .padding(.horizontal, DSTheme.Spacing.medium)
        .padding(.vertical, 8)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 10)
    }

    private var activeRepository: any BloodPressureReadingRepository {
        repository ?? SwiftDataBloodPressureReadingRepository(modelContext: modelContext)
    }

    private func saveReading() {
        guard viewModel.validate() else {
            return
        }

        if let existingReading {
            Task {
                guard await viewModel.update(
                    existingReading,
                    userId: userId,
                    repository: activeRepository
                ) else {
                    return
                }

                onSaveSuccess(viewModel.draft)
            }
        } else {
            do {
                let clientId = UUID()
                try activeRepository.save(viewModel.makeReading(userId: userId, clientId: clientId))
                try GRDBLocalReadingStore.shared.enqueue(viewModel.draft, userId: userId, clientId: clientId)
                onSaveSuccess(viewModel.draft)
            } catch {
                viewModel.setSaveError(error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BPConfirmReadingView(
            draft: BPReadingDraft(),
            repository: MockBloodPressureReadingRepository()
        )
    }
}

private struct BPConfirmNumberRow: View {
    let imageName: String
    let title: String
    @Binding var text: String
    let unit: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 16) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(Circle())

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

            Spacer(minLength: 10)

            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))
                .frame(width: 74)

            Text(unit)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(red: 0.26, green: 0.34, blue: 0.58))
                .frame(width: 42, alignment: .leading)

            Image(systemName: "pencil")
                .font(.headline.weight(.bold))
                .foregroundStyle(DSTheme.Color.primary)
                .frame(width: 24, height: 24)
        }
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }
}

private struct BPConfirmTimeRow: View {
    @Binding var date: Date

    var body: some View {
        HStack(spacing: 16) {
            Image("BPConfirmTimeIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(Circle())

            Text("时间")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(red: 0.04, green: 0.12, blue: 0.42))

            Spacer(minLength: 10)

            DatePicker(
                "",
                selection: $date,
                in: ...Date(),
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "zh_Hans"))
            .tint(DSTheme.Color.primary)
            .frame(maxWidth: 128, alignment: .trailing)

            Image(systemName: "pencil")
                .font(.headline.weight(.bold))
                .foregroundStyle(DSTheme.Color.primary)
                .frame(width: 24, height: 24)
        }
        .frame(minHeight: 72)
    }
}

private struct BPConfirmDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 58)
    }
}

@MainActor
final class BPConfirmReadingViewModel: ObservableObject {
    @Published var draft: BPReadingDraft
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false

    private let apiService: BloodPressureReadingAPIService
    private let localReadingStore: GRDBLocalReadingStore

    init(
        draft: BPReadingDraft,
        apiService: BloodPressureReadingAPIService? = nil,
        localReadingStore: GRDBLocalReadingStore? = nil
    ) {
        self.draft = draft
        self.apiService = apiService ?? BloodPressureReadingAPIService()
        self.localReadingStore = localReadingStore ?? .shared
    }

    func validate() -> Bool {
        let systolicText = draft.systolic.trimmingCharacters(in: .whitespacesAndNewlines)
        let diastolicText = draft.diastolic.trimmingCharacters(in: .whitespacesAndNewlines)
        let pulseText = draft.pulse.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !systolicText.isEmpty else {
            errorMessage = "请输入收缩压。"
            return false
        }

        guard !diastolicText.isEmpty else {
            errorMessage = "请输入舒张压。"
            return false
        }

        guard let systolic = Int(systolicText), let diastolic = Int(diastolicText) else {
            errorMessage = "收缩压和舒张压需要是数字。"
            return false
        }

        guard (40...260).contains(systolic) else {
            errorMessage = "收缩压应在 40–260 mmHg 之间。"
            return false
        }

        guard (30...180).contains(diastolic) else {
            errorMessage = "舒张压应在 30–180 mmHg 之间。"
            return false
        }

        guard systolic > diastolic else {
            errorMessage = "收缩压需要大于舒张压。"
            return false
        }

        if !pulseText.isEmpty {
            guard let pulse = Int(pulseText) else {
                errorMessage = "心率需要是数字，或留空。"
                return false
            }

            guard (30...240).contains(pulse) else {
                errorMessage = "心率应在 30–240 bpm 之间，或留空。"
                return false
            }
        }

        guard draft.measuredAt <= Date() else {
            errorMessage = "测量时间不能晚于当前时间。"
            return false
        }

        errorMessage = nil
        return true
    }

    func update(
        _ reading: BloodPressureReading,
        userId: String,
        repository: any BloodPressureReadingRepository
    ) async -> Bool {
        guard validate(), !isSaving else {
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try repository.update(reading, with: draft)
            try localReadingStore.upsertPending(draft, userId: userId, clientId: reading.id)
        } catch {
            setSaveError(error)
            return false
        }

        guard let serverId = reading.serverId else {
            errorMessage = nil
            return true
        }

        do {
            let response = try await apiService.update(id: serverId, draft: draft)
            try repository.upsertRemote(response.reading, userId: userId)
            try localReadingStore.markSynced(clientId: reading.id, serverId: response.reading.id)
        } catch {
            // The local edit remains queued and will be retried by the normal sync flow.
        }

        errorMessage = nil
        return true
    }

    func makeReading(userId: String, clientId: UUID = UUID()) -> BloodPressureReading {
        BloodPressureReading(
            id: clientId,
            userId: userId,
            systolic: Int(draft.systolic.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            diastolic: Int(draft.diastolic.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            pulse: parsedPulse,
            measuredAt: draft.measuredAt,
            source: draft.source
        )
    }

    func setSaveError(_ error: Error) {
        errorMessage = "保存读数失败，请稍后重试。"
    }

    private var parsedPulse: Int? {
        let pulseText = draft.pulse.trimmingCharacters(in: .whitespacesAndNewlines)
        return pulseText.isEmpty ? nil : Int(pulseText)
    }
}
