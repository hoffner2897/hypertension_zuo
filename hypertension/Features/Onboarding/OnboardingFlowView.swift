//
//  OnboardingFlowView.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import SwiftUI

struct OnboardingFlowView: View {
    let onComplete: () -> Void
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            HealthConnectView(
                onConnect: {
                    path.append(.syncedHealthData)
                },
                onSkip: {
                    onComplete()
                }
            )
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .syncedHealthData:
                    SyncedHealthDataView(
                        onContinue: onComplete,
                        onResync: {}
                    )
                }
            }
        }
    }
}

private enum OnboardingStep: Hashable {
    case syncedHealthData
}

#Preview {
    OnboardingFlowView {}
}
