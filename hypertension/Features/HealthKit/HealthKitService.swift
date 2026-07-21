import Foundation
import HealthKit

struct HealthKitSummary: Hashable {
    var authorizationStatus: HealthKitAuthorizationState = .notDetermined
    var latestRestingHeartRate: Double? = nil
    var todaySteps: Double? = nil
    var todayExerciseMinutes: Double? = nil
    var recentSleep: [HealthKitSleepSummary] = []
    var latestBodyMassKg: Double? = nil
    var latestHeightCm: Double? = nil
    var birthYear: Int? = nil
    var biologicalSex: String? = nil
    var lastUpdatedAt: Date? = nil
    var readableDataKinds: Set<HealthKitDataKind> = []
}

struct HealthKitSleepSummary: Identifiable, Hashable {
    let id = UUID()
    let day: Date
    let hours: Double
}

enum HealthKitAuthorizationState: Hashable {
    case unavailable
    case notDetermined
    case accessRequested
    case partiallyAuthorized
    case sharingAuthorized
}

enum HealthKitDataKind: String, CaseIterable, Hashable {
    case birthYear
    case biologicalSex
    case height
    case bodyMass
    case steps
    case exerciseMinutes
    case restingHeartRate
    case sleep
}

enum HealthKitAuthorizationResolver {
    static func resolve(
        isAvailable: Bool,
        hasRequestedAuthorization: Bool,
        readableDataKindCount: Int,
        requestedDataKindCount: Int = HealthKitDataKind.allCases.count
    ) -> HealthKitAuthorizationState {
        guard isAvailable else {
            return .unavailable
        }

        guard hasRequestedAuthorization else {
            return .notDetermined
        }

        guard readableDataKindCount > 0 else {
            return .accessRequested
        }

        if readableDataKindCount < requestedDataKindCount {
            return .partiallyAuthorized
        }

        return .sharingAuthorized
    }
}

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case missingTypes

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health is not available on this device."
        case .missingTypes:
            "Required Apple Health data types are unavailable."
        }
    }
}

final class HealthKitService {
    private let healthStore = HKHealthStore()
    private let authorizationRequestedKey = "bphealth.healthkit.authorizationRequested"

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationState() -> HealthKitAuthorizationState {
        HealthKitAuthorizationResolver.resolve(
            isAvailable: isHealthDataAvailable,
            hasRequestedAuthorization: hasRequestedAuthorization,
            readableDataKindCount: 0
        )
    }

    func requestAuthorization() async throws -> HealthKitAuthorizationState {
        guard isHealthDataAvailable else {
            throw HealthKitServiceError.unavailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes())
        UserDefaults.standard.set(true, forKey: authorizationRequestedKey)
        return .accessRequested
    }

    func fetchSummary() async throws -> HealthKitSummary {
        guard isHealthDataAvailable else {
            return HealthKitSummary(authorizationStatus: .unavailable)
        }

        let authorizationStatus = authorizationState()
        guard authorizationStatus != .notDetermined else {
            return HealthKitSummary(authorizationStatus: authorizationStatus)
        }

        async let restingHeartRate = try? latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let steps = try? todayCumulativeQuantity(.stepCount, unit: .count())
        async let exerciseMinutes = try? todayCumulativeQuantity(.appleExerciseTime, unit: .minute())
        async let sleep = try? recentSleepSummaries()
        async let bodyMass = try? latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        async let height = try? latestQuantity(.height, unit: .meterUnit(with: .centi))

        let resolvedRestingHeartRate = await restingHeartRate
        let resolvedSteps = await steps
        let resolvedExerciseMinutes = await exerciseMinutes
        let resolvedSleep = await sleep ?? []
        let resolvedBodyMass = await bodyMass
        let resolvedHeight = await height
        let resolvedBirthYear = try? dateOfBirthYear()
        let resolvedBiologicalSex = try? biologicalSex()

        var readableDataKinds: Set<HealthKitDataKind> = []
        if resolvedBirthYear != nil { readableDataKinds.insert(.birthYear) }
        if resolvedBiologicalSex != nil { readableDataKinds.insert(.biologicalSex) }
        if resolvedHeight != nil { readableDataKinds.insert(.height) }
        if resolvedBodyMass != nil { readableDataKinds.insert(.bodyMass) }
        if resolvedSteps != nil { readableDataKinds.insert(.steps) }
        if resolvedExerciseMinutes != nil { readableDataKinds.insert(.exerciseMinutes) }
        if resolvedRestingHeartRate != nil { readableDataKinds.insert(.restingHeartRate) }
        if !resolvedSleep.isEmpty { readableDataKinds.insert(.sleep) }

        return HealthKitSummary(
            authorizationStatus: HealthKitAuthorizationResolver.resolve(
                isAvailable: true,
                hasRequestedAuthorization: hasRequestedAuthorization,
                readableDataKindCount: readableDataKinds.count
            ),
            latestRestingHeartRate: resolvedRestingHeartRate,
            todaySteps: resolvedSteps,
            todayExerciseMinutes: resolvedExerciseMinutes,
            recentSleep: resolvedSleep,
            latestBodyMassKg: resolvedBodyMass,
            latestHeightCm: resolvedHeight,
            birthYear: resolvedBirthYear,
            biologicalSex: resolvedBiologicalSex,
            lastUpdatedAt: Date(),
            readableDataKinds: readableDataKinds
        )
    }

    private var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: authorizationRequestedKey)
    }

    private func readTypes() throws -> Set<HKObjectType> {
        guard
            let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
            let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
            let height = HKObjectType.quantityType(forIdentifier: .height),
            let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
            let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)
        else {
            throw HealthKitServiceError.missingTypes
        }

        return [restingHeartRate, steps, exerciseTime, sleep, bodyMass, height, biologicalSex, dateOfBirth]
    }

    private func dateOfBirthYear() throws -> Int? {
        try healthStore.dateOfBirthComponents().year
    }

    private func biologicalSex() throws -> String? {
        switch try healthStore.biologicalSex().biologicalSex {
        case .female:
            return "female"
        case .male:
            return "male"
        case .other:
            return "other"
        case .notSet:
            return nil
        @unknown default:
            return nil
        }
    }

    private func latestQuantitySample(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> (value: Double, measuredAt: Date)? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingTypes
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .year, value: -2, to: Date()),
            end: Date(),
            options: [.strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: (
                    value: sample.quantity.doubleValue(for: unit),
                    measuredAt: sample.startDate
                ))
            }

            healthStore.execute(query)
        }
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingTypes
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .year, value: -1, to: Date()),
            end: Date(),
            options: [.strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }

    private func todayCumulativeQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return try await cumulativeQuantity(identifier, unit: unit, start: startOfDay, end: Date())
    }

    private func cumulativeQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingTypes
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }

    private func recentSleepSummaries() async throws -> [HealthKitSleepSummary] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.missingTypes
        }

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: Date())) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [.strictEndDate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let groupedDurations = Dictionary(grouping: (samples ?? [])
                    .compactMap { $0 as? HKCategorySample }
                    .filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    }) { sample in
                        calendar.startOfDay(for: sample.endDate)
                    }

                let summaries = groupedDurations
                    .map { day, samples in
                        let totalSeconds = samples.reduce(0) { partial, sample in
                            partial + sample.endDate.timeIntervalSince(sample.startDate)
                        }
                        return HealthKitSleepSummary(day: day, hours: totalSeconds / 3600)
                    }
                    .filter { $0.hours > 0 }
                    .sorted { $0.day > $1.day }

                continuation.resume(returning: summaries)
            }

            healthStore.execute(query)
        }
    }
}
