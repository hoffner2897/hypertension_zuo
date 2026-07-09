//
//  hypertensionTests.swift
//  hypertensionTests
//
//  Created by Haoyu Zuo on 2026/6/27.
//

import Testing
import Foundation
@testable import hypertension

struct hypertensionTests {

    @Test @MainActor func validationAcceptsValidReading() async throws {
        let viewModel = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "128",
                diastolic: "82",
                pulse: "72",
                measuredAt: Date()
            )
        )

        #expect(viewModel.validate())
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func validationRequiresSystolic() async throws {
        let viewModel = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "",
                diastolic: "82",
                measuredAt: Date()
            )
        )

        #expect(!viewModel.validate())
        #expect(viewModel.errorMessage == "请输入收缩压。")
    }

    @Test @MainActor func validationRequiresSystolicGreaterThanDiastolic() async throws {
        let viewModel = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "80",
                diastolic: "82",
                measuredAt: Date()
            )
        )

        #expect(!viewModel.validate())
        #expect(viewModel.errorMessage == "收缩压需要大于舒张压。")
    }

    @Test @MainActor func validationRejectsFutureMeasurementTime() async throws {
        let viewModel = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "128",
                diastolic: "82",
                measuredAt: Date().addingTimeInterval(60)
            )
        )

        #expect(!viewModel.validate())
        #expect(viewModel.errorMessage == "测量时间不能晚于当前时间。")
    }

}
