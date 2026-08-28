//
//  BloodPressureRecognitionService.swift
//  hypertension
//
//  Created by Codex on 2026/6/27.
//

import Foundation

struct BPRecognitionResult: Hashable {
    var systolic: Int?
    var diastolic: Int?
    var pulse: Int?
    var confidence: Double
    var needsManualReview: Bool
    var notes: String?

    var draft: BPReadingDraft {
        BPReadingDraft(
            source: .cameraRecognition,
            systolic: systolic.map(String.init) ?? "",
            diastolic: diastolic.map(String.init) ?? "",
            pulse: pulse.map(String.init) ?? "",
            measuredAt: Date()
        )
    }
}

enum BPRecognitionError: LocalizedError {
    case missingImage
    case invalidResponse
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .missingImage:
            L10n.string("请先选择或拍摄一张血压计照片。")
        case .invalidResponse:
            L10n.string("识别结果格式不正确，请手动输入读数。")
        case .serviceUnavailable:
            L10n.string("暂时无法识别照片，请稍后重试或手动输入。")
        }
    }
}

@MainActor
protocol BloodPressureRecognitionService {
    func recognizeReading(from imageData: Data?) async throws -> BPRecognitionResult
}

@MainActor
struct MockBloodPressureRecognitionService: BloodPressureRecognitionService {
    func recognizeReading(from imageData: Data?) async throws -> BPRecognitionResult {
        try? await Task.sleep(for: .milliseconds(650))

        return BPRecognitionResult(
            systolic: 128,
            diastolic: 82,
            pulse: 72,
            confidence: 0.86,
            needsManualReview: false,
            notes: L10n.string("mock 识别结果，请用户确认。")
        )
    }
}

struct RemoteBPRecognitionRequest: Encodable {
    let imageBase64: String
}

struct RemoteBPRecognitionResponse: Decodable {
    let systolic: Int?
    let diastolic: Int?
    let pulse: Int?
    let confidence: Double?
    let needsManualReview: Bool?
    let notes: String?
}

@MainActor
struct RemoteBloodPressureRecognitionService: BloodPressureRecognitionService {
    var apiClient: APIClient = .shared

    func recognizeReading(from imageData: Data?) async throws -> BPRecognitionResult {
        guard let imageData else {
            throw BPRecognitionError.missingImage
        }

        let decoded: RemoteBPRecognitionResponse = try await apiClient.post(
            "/recognize-bp",
            body: RemoteBPRecognitionRequest(imageBase64: imageData.base64EncodedString()),
            requiresAuth: true
        )
        return BPRecognitionResult(
            systolic: decoded.systolic,
            diastolic: decoded.diastolic,
            pulse: decoded.pulse,
            confidence: decoded.confidence ?? 0,
            needsManualReview: decoded.needsManualReview ?? true,
            notes: decoded.notes
        )
    }
}
