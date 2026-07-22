import Testing
@testable import hypertension

@MainActor
struct ExerciseRecommendationEngineTests {
    @Test func catalogContainsFourScenesWithSixExercisesEach() {
        #expect(LowBarrierExerciseCatalog.all.count == 24)
        #expect(Set(LowBarrierExerciseCatalog.all.map(\.id)).count == 24)

        for scene in ExerciseScene.allCases {
            let exercises = LowBarrierExerciseCatalog.exercises(in: scene)
            #expect(exercises.count == 6)
            #expect(exercises.allSatisfy { !$0.movementAdvice.isEmpty })
            #expect(exercises.allSatisfy { !$0.intensityAdvice.isEmpty })
            #expect(exercises.allSatisfy { $0.movementAdviceSteps.count == 3 })
        }
    }

    @Test func everyContextScoreUsesAnAllowedExplicitValue() {
        let scoredContexts = ExerciseContext.allCases.filter { $0 != .noSpecialCondition }
        let allowed = Set([-3, -1, 1, 3])

        for exercise in LowBarrierExerciseCatalog.all {
            for context in scoredContexts {
                #expect(allowed.contains(exercise.contextScores[context]))
            }
            #expect(exercise.contextScores[.noSpecialCondition] == 0)
        }
    }

    @Test func everySceneReturnsExactlyFourUniqueSceneFilteredRecommendations() {
        for scene in ExerciseScene.allCases {
            for energy in ExerciseEnergyTier.allCases {
                let recommendations = ExerciseRecommendationEngine.recommendations(
                    scene: scene,
                    energy: energy,
                    contexts: [.afterMeal, .afterSitting]
                )

                #expect(recommendations.count == 4)
                #expect(Set(recommendations.map(\.id)).count == 4)
                #expect(recommendations.allSatisfy { $0.scene == scene })
                #expect(recommendations.filter { $0.type == .isometric }.count <= 1)
            }
        }
    }

    @Test func mixedTypeScenesKeepAerobicAndNonAerobicChoices() {
        let mixedScenes = ExerciseScene.allCases.filter { scene in
            let catalog = LowBarrierExerciseCatalog.exercises(in: scene)
            return catalog.contains(where: { $0.type.isAerobic }) &&
                catalog.contains(where: { !$0.type.isAerobic })
        }

        for scene in mixedScenes {
            let recommendations = ExerciseRecommendationEngine.recommendations(
                scene: scene,
                energy: .medium,
                contexts: [.afterSitting]
            )
            #expect(recommendations.contains(where: { $0.type.isAerobic }))
            #expect(recommendations.contains(where: { !$0.type.isAerobic }))
        }
    }

    @Test func lowEnergyAndSleepDeprivationAvoidWallSitsAndLowSteps() {
        for scene in ExerciseScene.allCases {
            let lowEnergy = ExerciseRecommendationEngine.recommendations(
                scene: scene,
                energy: .low,
                contexts: [.noSpecialCondition]
            )
            let sleepDeprived = ExerciseRecommendationEngine.recommendations(
                scene: scene,
                energy: .low,
                contexts: [.sleepDeprived]
            )

            for recommendations in [lowEnergy, sleepDeprived] {
                #expect(!recommendations.contains(where: { $0.name == "靠墙静蹲" }))
                #expect(!recommendations.contains(where: { $0.name == "低台阶踏步" }))
            }
        }
    }

    @Test func multiContextScoringIsAdditiveAndDeterministic() throws {
        let contexts: Set<ExerciseContext> = [.afterMeal, .afterStress, .afterActivity]
        let first = ExerciseRecommendationEngine.rankedRecommendations(
            scene: .publicIndoor,
            energy: .medium,
            contexts: contexts
        )
        let second = ExerciseRecommendationEngine.rankedRecommendations(
            scene: .publicIndoor,
            energy: .medium,
            contexts: [.afterActivity, .afterMeal, .afterStress]
        )

        #expect(first == second)
        let exercise = try #require(LowBarrierExerciseCatalog.exercise(id: "public-indoor-march-in-place"))
        let expectedContextScore = exercise.contextScores[.afterMeal]
            + exercise.contextScores[.afterStress]
            + exercise.contextScores[.afterActivity]
        let ranked = try #require(first.first(where: { $0.exercise.id == exercise.id }))
        #expect(ranked.contextScore == expectedContextScore)
        #expect(ranked.score == ranked.energyScore + ranked.contextScore)
    }

    @Test func stringAdapterAcceptsWorkbookAndUIOutdoorSlashVariants() {
        let workbookVariant = ExerciseRecommendationEngine.recommendations(
            sceneTitle: "私人／开放室外",
            energyTitle: "精力一般",
            contextTitles: ["久坐后"]
        )
        let uiVariant = ExerciseRecommendationEngine.recommendations(
            sceneTitle: "私人/开放室外",
            energyTitle: "精力一般",
            contextTitles: ["久坐后"]
        )

        #expect(workbookVariant.count == 4)
        #expect(workbookVariant == uiVariant)
    }
}
