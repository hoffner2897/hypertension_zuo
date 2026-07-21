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

            ScrollView {
                VStack(alignment: .leading, spacing: DSTheme.Spacing.large) {
                    DSSectionHeader(
                        existingReading == nil ? "确认读数" : "编辑读数",
                        subtitle: existingReading == nil
                            ? "检查并调整本次血压读数，保存后回到最近测量。"
                            : "修改后会更新历史记录，并在联网时同步。",
                        systemImage: "square.and.pencil"
                    )

                    DSCard {
                        VStack(alignment: .leading, spacing: DSTheme.Spacing.medium) {
                            DSChip(viewModel.draft.source.label, systemImage: sourceIcon)

                            DSInputRow(
                                title: "收缩压",
                                text: $viewModel.draft.systolic,
                                unit: "mmHg",
                                systemImage: "arrow.up.heart",
                                placeholder: "必填"
                            )

                            DSInputRow(
                                title: "舒张压",
                                text: $viewModel.draft.diastolic,
                                unit: "mmHg",
                                systemImage: "arrow.down.heart",
                                placeholder: "必填"
                            )

                            DSInputRow(
                                title: "心率",
                                text: $viewModel.draft.pulse,
                                unit: "bpm",
                                systemImage: "waveform.path.ecg",
                                placeholder: "可选"
                            )

                            DatePicker(
                                "测量时间",
                                selection: $viewModel.draft.measuredAt,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DSTheme.Color.textPrimary)
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

                    DSPrimaryButton(existingReading == nil ? "保存读数" : "更新读数", systemImage: "checkmark.circle.fill") {
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
                    .disabled(viewModel.isSaving)
                }
                .padding(DSTheme.Spacing.large)
            }
        }
        .navigationTitle(existingReading == nil ? "确认读数" : "编辑读数")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sourceIcon: String {
        switch viewModel.draft.source {
        case .cameraRecognition:
            "camera.fill"
        case .manual:
            "square.and.pencil"
        }
    }

    private var activeRepository: any BloodPressureReadingRepository {
        repository ?? SwiftDataBloodPressureReadingRepository(modelContext: modelContext)
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
