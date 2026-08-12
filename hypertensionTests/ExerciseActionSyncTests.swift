import Foundation
import Testing
@testable import hypertension

struct ExerciseActionSyncTests {
    @Test @MainActor func localHistoryKeepsExerciseIdentityAndFixedAdvice() throws {
        let userId = "exercise-history-\(UUID().uuidString)"
        defer { ActionHistoryStore.removeAll(userId: userId) }

        let exercise = try #require(
            LowBarrierExerciseCatalog.exercise(id: "private-indoor-seated-alternating-knee-lift")
        )
        let item = TodayActionItem.generatedMovement(
            title: exercise.name,
            timeText: "16:00",
            duration: 10,
            order: 99,
            exercise: exercise,
            scene: ExerciseScene.privateIndoor.rawValue,
            energy: ExerciseEnergyTier.low.title,
            contexts: [ExerciseContext.sleepDeprived.rawValue]
        )

        ActionHistoryStore.saveToday([item], userId: userId)
        let restored = ActionHistoryStore.restoreToday([], userId: userId)
        let restoredItem = try #require(restored.first)

        #expect(restoredItem.exerciseId == exercise.id)
        #expect(restoredItem.exerciseScene == ExerciseScene.privateIndoor.rawValue)
        #expect(restoredItem.exerciseEnergy == ExerciseEnergyTier.low.title)
        #expect(restoredItem.exerciseContexts == [ExerciseContext.sleepDeprived.rawValue])
        #expect(restoredItem.exerciseMovementAdvice == exercise.movementAdvice)
        #expect(restoredItem.exerciseIntensityAdvice == exercise.intensityAdvice)
    }

    @Test @MainActor func syncRoundTripPreservesCompletionAndClientTimestamp() throws {
        let exercise = try #require(
            LowBarrierExerciseCatalog.exercise(id: "public-indoor-slow-walk")
        )
        let id = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_790_000_000)
        let completedAt = scheduledAt.addingTimeInterval(600)
        let clientUpdatedAt = completedAt.addingTimeInterval(5)
        let item = TodayActionItem(
            id: id,
            type: .walk,
            title: exercise.name,
            description: exercise.movementAdvice,
            reason: "推荐运动",
            scheduledStartAt: scheduledAt,
            durationMinutes: 10,
            status: .completed,
            completedAt: completedAt,
            sortOrder: 0,
            exerciseId: exercise.id,
            exerciseScene: exercise.scene.rawValue,
            exerciseEnergy: ExerciseEnergyTier.medium.title,
            exerciseContexts: [ExerciseContext.afterMeal.rawValue],
            exerciseMovementAdvice: exercise.movementAdvice,
            exerciseIntensityAdvice: exercise.intensityAdvice,
            clientUpdatedAt: clientUpdatedAt
        )

        let input = try #require(ExerciseActionSyncInput(item: item))
        #expect(input.exerciseId == exercise.id)
        #expect(input.status == "completed")
        #expect(input.completedAt != nil)

        let remote = RemoteExerciseAction(
            id: id.uuidString,
            exerciseId: input.exerciseId,
            title: input.title,
            scene: input.scene,
            energy: input.energy,
            contexts: input.contexts,
            scheduledStartAt: input.scheduledStartAt,
            durationMinutes: input.durationMinutes,
            status: input.status,
            completedAt: input.completedAt,
            movementAdvice: input.movementAdvice,
            intensityAdvice: input.intensityAdvice,
            localDay: input.localDay,
            clientUpdatedAt: input.clientUpdatedAt,
            createdAt: input.clientUpdatedAt,
            updatedAt: input.clientUpdatedAt
        )
        let restored = try #require(TodayActionItem(remoteExerciseAction: remote))

        #expect(restored.id == id)
        #expect(restored.status == .completed)
        #expect(restored.exerciseId == exercise.id)
        #expect(restored.exerciseMovementAdvice == exercise.movementAdvice)
        #expect(restored.exerciseIntensityAdvice == exercise.intensityAdvice)
        #expect(abs(restored.clientUpdatedAt.timeIntervalSince(clientUpdatedAt)) < 0.001)
    }

    @Test @MainActor func timerResearchFieldsSurviveLocalAndRemoteRoundTrips() throws {
        let userId = "exercise-timer-\(UUID().uuidString)"
        defer { ActionHistoryStore.removeAll(userId: userId) }
        let startedAt = Date().addingTimeInterval(-620)
        let endedAt = startedAt.addingTimeInterval(615)
        let exercise = try #require(LowBarrierExerciseCatalog.exercise(id: "public-indoor-slow-walk"))
        var item = TodayActionItem.generatedMovement(
            title: "慢走", timeText: TodayActionItem.timeFormatter.string(from: startedAt), duration: 10, order: 8,
            exercise: exercise, scene: exercise.scene.rawValue, energy: ExerciseEnergyTier.medium.title
        )
        item.status = .completed
        item.completedAt = endedAt
        item.actualStartedAt = startedAt
        item.actualEndedAt = endedAt
        item.timerAccumulatedSeconds = 615
        item.actualDurationSeconds = 615
        item.completionMode = .timerCompleted

        ActionHistoryStore.saveToday([item], userId: userId)
        let restored = try #require(ActionHistoryStore.restoreToday([], userId: userId).first)
        #expect(restored.actualDurationSeconds == 615)
        #expect(restored.completionMode == .timerCompleted)

        if let input = ExerciseActionSyncInput(item: item) {
            #expect(input.actualDurationSeconds == 615)
            #expect(input.completionMode == "timer_completed")
        }
    }
}
