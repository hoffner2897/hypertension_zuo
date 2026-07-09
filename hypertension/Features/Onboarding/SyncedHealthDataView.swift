//
//  SyncedHealthDataView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct SyncedHealthDataView: View {
    let onContinue: () -> Void
    var onResync: () -> Void = {}
    @StateObject private var viewModel = HealthKitSummaryViewModel()
    @State private var isEditingData = false

    var body: some View {
        SyncedHealthDataContent(
            viewModel: viewModel,
            primaryTitle: "完成",
            primaryIcon: "checkmark",
            isPrimaryDisabled: !viewModel.hasRequiredData,
            onPrimary: {
                Task {
                    if await viewModel.completeSyncedData() {
                        onContinue()
                    }
                }
            },
            secondaryTitle: "重新同步",
            secondaryIcon: "arrow.clockwise",
            onSecondary: {
                Task {
                    await viewModel.refresh()
                    onResync()
                }
            }
        )
        .navigationTitle("同步数据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingData = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("手动补充基础数据")
            }
        }
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
}

#Preview {
    NavigationStack {
        SyncedHealthDataView(onContinue: {})
    }
}
