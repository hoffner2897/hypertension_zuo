import Foundation
import UIKit

enum MealKind: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner

    var displayName: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        }
    }

    init?(actionTitle: String) {
        if actionTitle.contains("早餐") {
            self = .breakfast
        } else if actionTitle.contains("午餐") {
            self = .lunch
        } else if actionTitle.contains("晚餐") {
            self = .dinner
        } else {
            return nil
        }
    }
}

struct MealRecord: Decodable, Identifiable, Equatable {
    let id: String
    let mealType: MealKind
    let mealDate: String
    let analysis: String
    let similarSuggestion: String
    let recognition: String?
    let dietaryStructureAnalysis: String?
    let cookingMethodAnalysis: String?
    let dietaryStructureSuggestion: String?
    let cookingMethodSuggestion: String?
    let cardSummary: String
    let recordedAt: String
    let createdAt: String
    let updatedAt: String
}

struct MealRecordService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func records(for date: Date = Date()) async throws -> [MealRecord] {
        let response: MealRecordListResponse = try await apiClient.get(
            "/meal-records?date=\(Self.dayFormatter.string(from: date))",
            requiresAuth: true
        )
        return response.records
    }

    func analyze(imageData: Data, mealType: MealKind, date: Date = Date()) async throws -> MealRecord {
        let response: MealAnalyzeResponse = try await apiClient.post(
            "/meal-records/analyze",
            body: MealAnalyzeRequest(
                mealType: mealType,
                mealDate: Self.dayFormatter.string(from: date),
                recordedAt: Self.isoFormatter.string(from: date),
                timeZone: TimeZone.current.identifier,
                imageBase64: "data:image/jpeg;base64,\(imageData.base64EncodedString())"
            ),
            requiresAuth: true
        )
        return response.record
    }

    static func uploadData(for image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1400
        let largestSide = max(image.size.width, image.size.height)
        let resizedImage: UIImage

        if largestSide > maxDimension {
            let scale = maxDimension / largestSide
            let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            resizedImage = image
        }

        return resizedImage.jpegData(compressionQuality: 0.76)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct MealRecordListResponse: Decodable {
    let records: [MealRecord]
}

private struct MealAnalyzeResponse: Decodable {
    let record: MealRecord
    let source: String
}

private struct MealAnalyzeRequest: Encodable {
    let mealType: MealKind
    let mealDate: String
    let recordedAt: String
    let timeZone: String
    let imageBase64: String
}
