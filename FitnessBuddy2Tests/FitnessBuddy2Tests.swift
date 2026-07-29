import Foundation
import Testing
@testable import FitnessBuddy2

@MainActor
struct FitnessBuddy2Tests {
    @Test func adaptivePlanFitsAvailabilityAndBecomesMatchingSession() throws {
        let profile = makeProfile(sessionsPerWeek: 4, sessionMinutes: 30)
        let data = freshStore()
        data.configure(for: profile)

        #expect(data.weeklyPlan.count == profile.sessionsPerWeek)
        #expect(data.weeklyPlan.allSatisfy { !$0.exercises.isEmpty })
        #expect(data.weeklyPlan.allSatisfy { $0.estimatedMinutes <= profile.sessionMinutes })

        let workout = try #require(data.weeklyPlan.first)
        data.startWorkout(workout)
        let session = try #require(data.activeSession)

        #expect(session.prescriptionID == workout.id)
        #expect(session.title == workout.title)
        #expect(session.focus == workout.focus)
        #expect(session.exercises.count == workout.exercises.count)

        for index in workout.exercises.indices {
            let planned = workout.exercises[index]
            let logged = session.exercises[index]
            #expect(logged.exercise.id == planned.exercise.id)
            #expect(logged.sets.count == planned.sets)
            #expect(logged.sets.allSatisfy { $0.targetRepMin == planned.repMin })
            #expect(logged.sets.allSatisfy { $0.targetRepMax == planned.repMax })
            #expect(logged.sets.allSatisfy { $0.targetRIR == planned.targetRIR })
        }
    }

    @Test func plannerSelectsTargetRIRFromTrainingAgeAndRecovery() throws {
        let trainedData = freshStore()
        trainedData.configure(for: makeProfile(trainingAgeMonths: 24, recoveryRating: 4))
        let trainedSummary = try #require(trainedData.programSummary)
        #expect(trainedSummary.targetRIR == 2)
        #expect(trainedData.weeklyPlan.flatMap(\.exercises).allSatisfy { $0.targetRIR == 2 })

        let noviceData = freshStore()
        noviceData.configure(
            for: makeProfile(
                experience: .beginner,
                trainingAgeMonths: 3,
                recoveryRating: 5
            )
        )
        let noviceSummary = try #require(noviceData.programSummary)
        #expect(noviceSummary.targetRIR == 3)
        #expect(noviceData.weeklyPlan.flatMap(\.exercises).allSatisfy { $0.targetRIR == 3 })

        let underRecoveredData = freshStore()
        underRecoveredData.configure(
            for: makeProfile(
                trainingAgeMonths: 24,
                recoveryRating: 2
            )
        )
        #expect(underRecoveredData.programSummary?.targetRIR == 3)
    }

    @Test func plannerHonorsEquipmentAndMovementConstraints() {
        let profile = makeProfile(
            equipment: [.dumbbells, .bodyweight],
            constraints: [.avoidOverhead, .lowerBackSensitive]
        )
        let data = freshStore()
        data.configure(for: profile)
        let exercises = data.weeklyPlan.flatMap(\.exercises).map(\.exercise)

        #expect(!exercises.isEmpty)
        #expect(exercises.allSatisfy {
            ExerciseCatalog.isAvailable($0, equipment: profile.equipment)
                && ExerciseCatalog.isPermitted($0, constraints: profile.constraints)
        })
        #expect(exercises.allSatisfy {
            let pattern = ExerciseCatalog.metadata(for: $0).pattern
            return pattern != .verticalPush && pattern != .lateralRaise
        })
        #expect(exercises.allSatisfy {
            let requirements = ExerciseCatalog.metadata(for: $0).equipment
            return requirements.contains(.bodyweight)
                || !requirements.isDisjoint(with: profile.equipment)
        })
    }

    @Test func scheduledDatesUseSelectedISOWeekdaysAndNeverFallInThePast() throws {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let profile = makeProfile(
            sessionsPerWeek: 2,
            preferredWeekdays: [1, 7]
        )
        let data = freshStore()
        data.configure(for: profile)

        #expect(data.weeklyPlan.count == 2)
        let scheduledDays = data.weeklyPlan.map { calendar.startOfDay(for: $0.scheduledDate) }
        #expect(scheduledDays == scheduledDays.sorted())

        let actualISOWeekdays = Set(scheduledDays.map { date in
            let appleWeekday = calendar.component(.weekday, from: date)
            return appleWeekday == 1 ? 7 : appleWeekday - 1
        })
        #expect(actualISOWeekdays == profile.preferredWeekdays)
        #expect(actualISOWeekdays.contains(7))

        for scheduledDay in scheduledDays {
            let daysFromToday = try #require(
                calendar.dateComponents([.day], from: today, to: scheduledDay).day
            )
            #expect((0...6).contains(daysFromToday))
        }
    }

    @Test func activeAndCompletedPrescriptionsCannotRestart() throws {
        let data = freshStore()
        data.configure(for: makeProfile(sessionsPerWeek: 2))
        let first = try #require(data.todayWorkout)
        let other = try #require(data.weeklyPlan.first(where: { $0.id != first.id }))

        #expect(data.startWorkout(first))
        #expect(!data.startWorkout(other))
        #expect(data.activeSession?.prescriptionID == first.id)

        let completed = try #require(data.finishActiveWorkout())
        #expect(completed.prescriptionID == first.id)
        #expect(!data.startWorkout(first))
        #expect(data.activeSession == nil)
        #expect(data.todayWorkout?.id != first.id)
    }

    @Test func baselineSeedsLoadWhileMissingBaselineRequiresCalibration() throws {
        let baseline = LiftBaseline(
            exerciseID: "barbell-bench",
            weightKG: 80,
            reps: 6,
            rir: 2,
            performedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let baselineProfile = makeProfile(
            sessionsPerWeek: 2,
            equipment: [.barbellRack],
            baselines: [baseline]
        )
        let baselineData = freshStore()
        baselineData.configure(for: baselineProfile)
        let seededBench = try prescription(for: "barbell-bench", in: baselineData)

        #expect(seededBench.targetWeightKG > 0)
        #expect(seededBench.loadSource == "Onboarding working set")
        #expect(seededBench.decisionNote?.contains("conservative starting load") == true)

        let calibrationData = freshStore()
        calibrationData.configure(
            for: makeProfile(
                sessionsPerWeek: 2,
                equipment: [.barbellRack]
            )
        )
        let calibrationBench = try prescription(for: "barbell-bench", in: calibrationData)

        #expect(calibrationBench.targetWeightKG == 0)
        #expect(calibrationBench.loadSource == "Calibration required")
        #expect(calibrationBench.decisionNote?.contains("first-session load") == true)
        #expect(calibrationData.weeklyPlan.contains { $0.rationale.contains("calibrat") })
    }

    @Test func completingASetStartsRestAndRegistersPR() throws {
        let profile = makeProfile()
        let data = freshStore()
        data.configure(for: profile)
        let workout = try #require(data.weeklyPlan.first)
        data.startWorkout(workout)
        data.updateWeight(exerciseIndex: 0, setIndex: 0, displayValue: 42.5, units: .metric)
        data.updateRIR(
            exerciseIndex: 0,
            setIndex: 0,
            rir: workout.exercises[0].effectiveTargetRIR
        )

        let isPR = data.toggleSet(exerciseIndex: 0, setIndex: 0)

        #expect(isPR)
        #expect(data.activeSession?.completedSetCount == 1)
        #expect(data.restEndsAt != nil)
        #expect(data.personalRecords.first?.exerciseID == workout.exercises[0].exercise.id)
    }

    @Test func loadIncreasesOnlyAfterTwoSuccessfulExposures() throws {
        let profile = progressionProfile()
        let data = freshStore()
        data.configure(for: profile)
        let initial = try prescription(for: "barbell-bench", in: data)
        #expect(initial.targetWeightKG > 0)

        let firstWorkout = try workout(containing: "barbell-bench", in: data)
        data.startWorkout(
            firstWorkout,
            startedAt: trainingDate(daysAgo: 2, hour: 9)
        )
        try completeExercise("barbell-bench", in: data)
        _ = data.finishActiveWorkout()
        let firstDecision = try #require(
            data.adaptationDecisions.first(where: { $0.exerciseID == "barbell-bench" })
        )

        #expect(firstDecision.direction == .hold)
        #expect(firstDecision.nextLoadKG == initial.targetWeightKG)

        data.configure(for: profile, force: true)
        let held = try prescription(for: "barbell-bench", in: data)
        #expect(held.targetWeightKG == initial.targetWeightKG)

        let secondWorkout = try workout(containing: "barbell-bench", in: data)
        data.startWorkout(
            secondWorkout,
            startedAt: trainingDate(daysAgo: 1, hour: 9)
        )
        try completeExercise("barbell-bench", in: data)
        _ = data.finishActiveWorkout()
        let secondDecision = try #require(
            data.adaptationDecisions.first(where: { $0.exerciseID == "barbell-bench" })
        )

        #expect(secondDecision.direction == .increase)
        #expect(secondDecision.nextLoadKG > secondDecision.previousLoadKG)

        data.configure(for: profile, force: true)
        let progressed = try prescription(for: "barbell-bench", in: data)
        #expect(progressed.targetWeightKG == secondDecision.nextLoadKG)
        #expect(progressed.decisionNote?.contains("Two top-range exposures") == true)
    }

    @Test func RIRIsRequiredOnPhoneAndWatchRIREarnsProgression() throws {
        let profile = progressionProfile()
        let data = freshStore()
        data.configure(for: profile)
        let initial = try prescription(for: "barbell-bench", in: data)
        let phoneWorkout = try workout(containing: "barbell-bench", in: data)

        #expect(data.startWorkout(phoneWorkout))
        let phoneSession = try #require(data.activeSession)
        let phoneExerciseIndex = try #require(
            phoneSession.exercises.firstIndex(where: { $0.exercise.id == "barbell-bench" })
        )
        data.updateReps(
            exerciseIndex: phoneExerciseIndex,
            setIndex: 0,
            reps: phoneSession.exercises[phoneExerciseIndex].sets[0].targetRepMax
        )
        _ = data.toggleSet(exerciseIndex: phoneExerciseIndex, setIndex: 0)
        #expect(data.activeSession?.exercises[phoneExerciseIndex].sets[0].isComplete == false)
        #expect(data.restEndsAt == nil)
        data.discardActiveWorkout()

        try completeExerciseFromWatch(
            "barbell-bench",
            workout: phoneWorkout,
            in: data,
            startedAt: trainingDate(daysAgo: 2, hour: 9)
        )
        data.configure(for: profile, force: true)
        let secondWorkout = try workout(containing: "barbell-bench", in: data)
        try completeExerciseFromWatch(
            "barbell-bench",
            workout: secondWorkout,
            in: data,
            startedAt: trainingDate(daysAgo: 1, hour: 9)
        )

        let decision = try #require(
            data.adaptationDecisions.first(where: { $0.exerciseID == "barbell-bench" })
        )
        #expect(decision.direction == .increase)
        #expect(decision.nextLoadKG > initial.targetWeightKG)
        let loggedBench = try #require(
            data.completedWorkouts.first?
                .exercises.first(where: { $0.exercise.id == "barbell-bench" })
        )
        #expect(
            loggedBench.sets.allSatisfy {
                $0.isComplete && $0.reportedRIR == $0.effectiveTargetRIR
            }
        )
    }

    @Test func sameDaySessionsCountAsOneProgressionExposure() throws {
        let profile = progressionProfile()
        let data = freshStore()
        data.configure(for: profile)
        let initial = try prescription(for: "barbell-bench", in: data)

        let firstWorkout = try workout(containing: "barbell-bench", in: data)
        #expect(
            data.startWorkout(
                firstWorkout,
                startedAt: trainingDate(daysAgo: 1, hour: 9)
            )
        )
        try completeExercise("barbell-bench", in: data)
        _ = data.finishActiveWorkout()

        data.configure(for: profile, force: true)
        let secondWorkout = try workout(containing: "barbell-bench", in: data)
        #expect(
            data.startWorkout(
                secondWorkout,
                startedAt: trainingDate(daysAgo: 1, hour: 17)
            )
        )
        try completeExercise("barbell-bench", in: data)
        _ = data.finishActiveWorkout()

        let decision = try #require(
            data.adaptationDecisions.first(where: { $0.exerciseID == "barbell-bench" })
        )
        #expect(decision.direction == .hold)

        data.configure(for: profile, force: true)
        let held = try prescription(for: "barbell-bench", in: data)
        #expect(held.targetWeightKG == initial.targetWeightKG)
    }

    @Test func bodyweightPrescriptionProgressesAfterTwoDistinctExposures() throws {
        let profile = makeProfile(
            sessionsPerWeek: 2,
            equipment: [.bodyweight]
        )
        let data = freshStore()
        data.configure(for: profile)
        let initial = try prescription(for: "push-up", in: data)
        #expect(initial.targetWeightKG == 0)

        let firstWorkout = try workout(containing: "push-up", in: data)
        #expect(
            data.startWorkout(
                firstWorkout,
                startedAt: trainingDate(daysAgo: 2, hour: 9)
            )
        )
        try completeExercise("push-up", in: data)
        _ = data.finishActiveWorkout()

        data.configure(for: profile, force: true)
        let secondWorkout = try workout(containing: "push-up", in: data)
        let secondPrescription = try #require(
            secondWorkout.exercises.first(where: { $0.exercise.id == "push-up" })
        )
        #expect(
            data.startWorkout(
                secondWorkout,
                startedAt: trainingDate(daysAgo: 1, hour: 9)
            )
        )
        try completeExercise("push-up", in: data)
        _ = data.finishActiveWorkout()

        let decision = try #require(
            data.adaptationDecisions.first(where: { $0.exerciseID == "push-up" })
        )
        #expect(decision.direction == .increase)
        #expect(decision.previousLoadKG == 0)
        #expect(decision.nextLoadKG == 0)

        data.configure(for: profile, force: true)
        let progressed = try prescription(for: "push-up", in: data)
        #expect(progressed.targetWeightKG == 0)
        #expect(progressed.loadSource == "Rep-based resistance")
        #expect(
            progressed.repMin > secondPrescription.repMin
                || progressed.repMax > secondPrescription.repMax
                || progressed.sets > secondPrescription.sets
        )
    }

    @Test func multipleUnexpectedlyHardSetsReduceNextLoad() throws {
        let profile = progressionProfile()
        let data = freshStore()
        data.configure(for: profile)
        let initial = try prescription(for: "barbell-bench", in: data)
        let workout = try workout(containing: "barbell-bench", in: data)
        data.startWorkout(workout)

        try completeExercise("barbell-bench", in: data, unexpectedlyHardSetCount: 2)
        _ = data.finishActiveWorkout()
        let decision = try #require(
            data.adaptationDecisions.first(where: { $0.exerciseID == "barbell-bench" })
        )

        #expect(decision.direction == .reduce)
        #expect(decision.previousLoadKG == initial.targetWeightKG)
        #expect(decision.nextLoadKG < decision.previousLoadKG)
        #expect(data.coachInsight.contains("reduction"))

        data.configure(for: profile, force: true)
        let reduced = try prescription(for: "barbell-bench", in: data)
        #expect(reduced.targetWeightKG == decision.nextLoadKG)
        #expect(reduced.decisionNote?.contains("reduced conservatively") == true)
    }

    @Test func coachRejectsMalformedRepRangeWithoutMutatingPlan() throws {
        let profile = makeProfile(sessionsPerWeek: 2)
        let data = freshStore()
        data.configure(for: profile)
        let originalPlan = data.weeklyPlan
        let originalSummary = try #require(data.programSummary)
        var proposal = mirroredCoachPlan(from: originalPlan)
        try #require(proposal.count == 2)
        try #require(!proposal[1].exercises.isEmpty)
        proposal[0].title = "MUST NOT LEAK"
        proposal[1].exercises[0].repMin = 12
        proposal[1].exercises[0].repMax = 8

        data.applyCoachResponse(
            CoachAPIResponse(
                reply: "Invalid proposal",
                insight: "This should be replaced.",
                plan: proposal
            ),
            profile: profile
        )

        #expect(data.weeklyPlan == originalPlan)
        #expect(data.programSummary == originalSummary)
        #expect(data.pendingCoachProposal == nil)
        #expect(
            data.coachInsight
                == "The AI proposal exceeded a programming guardrail, so your validated local plan stayed active."
        )
    }

    @Test func coachRejectsCalculatedOverlongPlanBeforeStaging() throws {
        let profile = makeProfile(sessionsPerWeek: 2, sessionMinutes: 55)
        let data = freshStore()
        data.configure(for: profile)
        let originalPlan = data.weeklyPlan
        var proposal = mirroredCoachPlan(from: originalPlan)
        let dayIndex = try #require(proposal.indices.first)

        proposal[dayIndex].estimatedMinutes = 20
        for exerciseIndex in proposal[dayIndex].exercises.indices {
            proposal[dayIndex].exercises[exerciseIndex].sets = 4
            proposal[dayIndex].exercises[exerciseIndex].restSeconds = 300
        }

        data.stageCoachResponse(
            CoachAPIResponse(
                reply: "Invalid proposal",
                insight: "The server claims this fits.",
                plan: proposal
            ),
            profile: profile
        )

        #expect(data.pendingCoachProposal == nil)
        #expect(data.weeklyPlan == originalPlan)
        #expect(data.weeklyPlan.allSatisfy { !$0.isAIEnhanced })
    }

    @Test func coachRejectsPlanWithoutMajorGroupBalanceBeforeStaging() throws {
        let profile = makeProfile(sessionsPerWeek: 2)
        let data = freshStore()
        data.configure(for: profile)
        let originalPlan = data.weeklyPlan
        var proposal = mirroredCoachPlan(from: originalPlan)
        var chestExerciseCount = 0

        for dayIndex in proposal.indices {
            for exerciseIndex in proposal[dayIndex].exercises.indices {
                let exerciseID = proposal[dayIndex].exercises[exerciseIndex].exerciseID
                if ExerciseCatalog.byID[exerciseID]?.muscle == .chest {
                    proposal[dayIndex].exercises[exerciseIndex].sets = 1
                    chestExerciseCount += 1
                }
            }
        }
        try #require(chestExerciseCount >= 2)

        data.stageCoachResponse(
            CoachAPIResponse(
                reply: "Invalid proposal",
                insight: "This week lacks balanced coverage.",
                plan: proposal
            ),
            profile: profile
        )

        #expect(data.pendingCoachProposal == nil)
        #expect(data.weeklyPlan == originalPlan)
    }

    @Test func validCoachProposalStagesThenAppliesAsOnePlan() throws {
        let profile = makeProfile(sessionsPerWeek: 2)
        let data = freshStore()
        data.configure(for: profile)
        let originalPlan = data.weeklyPlan
        var proposal = mirroredCoachPlan(from: originalPlan)
        proposal[0].title = "accepted baseline"
        let response = CoachAPIResponse(
            reply: "Valid proposal",
            insight: "Ready to apply.",
            plan: proposal
        )

        data.stageCoachResponse(response, profile: profile)
        #expect(data.pendingCoachProposal == response)
        #expect(data.weeklyPlan == originalPlan)

        data.applyPendingCoachProposal(profile: profile)
        #expect(data.pendingCoachProposal == nil)
        #expect(data.weeklyPlan[0].title == "ACCEPTED BASELINE")
        #expect(data.weeklyPlan.allSatisfy { $0.isAIEnhanced })
    }

    @Test func watchSetCanStartAndUpdateMatchingWorkout() throws {
        let profile = makeProfile()
        let data = freshStore()
        data.configure(for: profile)
        let workout = try #require(data.weeklyPlan.first)
        let exercise = try #require(workout.exercises.first)
        let event = try #require(WatchCompletedSetEvent(dictionary: [
            "type": "completedSet",
            "eventID": UUID().uuidString,
            "workoutID": workout.id.uuidString,
            "exerciseID": exercise.exercise.id,
            "setNumber": 1,
            "weightKG": 42.5,
            "reps": 7,
            "reportedRIR": 1,
            "completedAt": Date(),
            "restSeconds": 90,
        ]))

        #expect(data.applyWatchCompletedSet(event))
        #expect(data.activeSession?.prescriptionID == workout.id)
        #expect(data.activeSession?.exercises[0].sets[0].isComplete == true)
        #expect(data.activeSession?.exercises[0].sets[0].weightKG == 42.5)
        #expect(data.activeSession?.exercises[0].sets[0].reps == 7)
        #expect(data.activeSession?.exercises[0].sets[0].reportedRIR == 1)
    }

    @Test func watchCompletionSnapshotIsAtomicAndTransfersHealthOwnership() throws {
        let profile = makeProfile()
        let data = freshStore()
        data.configure(for: profile)
        let workout = try #require(data.weeklyPlan.first)
        let exercise = try #require(workout.exercises.first)
        #expect(data.startWorkout(workout))
        #expect(data.activeSession?.recordingOwner == .phone)
        let endedAt = Date()
        let startedAt = endedAt.addingTimeInterval(-1_800)

        let snapshots: [[String: Any]] = (1...exercise.sets).map { setNumber in
            [
                "eventID": "snapshot-\(setNumber)",
                "exerciseID": exercise.exercise.id,
                "setNumber": setNumber,
                "weightKG": exercise.targetWeightKG,
                "reps": exercise.repMax,
                "reportedRIR": exercise.effectiveTargetRIR,
                "completedAt": Date(),
                "restSeconds": exercise.restSeconds,
            ]
        }
        let completion = try #require(WatchCompletedWorkoutEvent(dictionary: [
            "type": "watchWorkoutCompleted",
            "workoutID": workout.id.uuidString,
            "startedAt": startedAt,
            "endedAt": endedAt,
            "completedSetSnapshots": snapshots,
        ]))
        #expect(completion.startedAt == startedAt)
        #expect(data.startWorkoutFromWatch(
            workoutID: completion.workoutID,
            startedAt: completion.startedAt
        ))

        for set in completion.completedSets {
            #expect(data.applyWatchCompletedSet(set))
        }
        let finished = try #require(data.finishWorkoutFromWatch(
            workoutID: completion.workoutID,
            endedAt: completion.endedAt
        ))

        #expect(finished.recordingOwner == .watch)
        #expect(finished.startedAt == startedAt)
        let finishedExercise = try #require(
            finished.exercises.first(where: { $0.exercise.id == exercise.exercise.id })
        )
        #expect(
            finishedExercise.sets.allSatisfy {
                $0.isComplete && $0.reportedRIR == exercise.effectiveTargetRIR
            }
        )
        #expect(data.applyWatchCompletedSet(completion.completedSets[0]) == false)
        #expect(data.completedWorkouts.count == 1)
    }

    @Test func exerciseIncrementsUseSensibleProfileUnits() throws {
        let bench = try #require(ExerciseCatalog.byID["barbell-bench"])
        let legPress = try #require(ExerciseCatalog.byID["leg-press"])
        let curl = try #require(ExerciseCatalog.byID["db-curl"])
        let poundsPerKilogram = 2.204_622_621_8

        #expect(ExerciseCatalog.incrementKG(for: bench, measurementSystem: .metric) == 2.5)
        #expect(
            abs(
                ExerciseCatalog.incrementKG(for: bench, measurementSystem: .imperial)
                    * poundsPerKilogram - 5
            ) < 0.001
        )
        #expect(
            abs(
                ExerciseCatalog.incrementKG(for: legPress, measurementSystem: .imperial)
                    * poundsPerKilogram - 10
            ) < 0.001
        )
        #expect(
            abs(
                ExerciseCatalog.incrementKG(for: curl, measurementSystem: .imperial)
                    * poundsPerKilogram - 2.5
            ) < 0.001
        )

        let data = freshStore()
        data.configure(for: makeProfile(measurementSystem: .imperial))
        let exercises = data.weeklyPlan.flatMap(\.exercises)
        #expect(exercises.allSatisfy { $0.measurementSystem == MeasurementSystem.imperial.rawValue })
        #expect(
            exercises.allSatisfy {
                $0.incrementKG == ExerciseCatalog.incrementKG(
                    for: $0.exercise,
                    measurementSystem: .imperial
                )
            }
        )
    }

    @Test func insightsTabUsesVisibleLightbulbSFSymbol() {
        #expect(AppTab.coach.title == "INSIGHTS")
        #expect(AppTab.coach.systemImage == "lightbulb.fill")
    }

    /// The Watch runs its own HKWorkoutSession and saves the workout to Health
    /// itself. Sessions it originates must stay flagged through completion so
    /// the phone skips its save and Health does not receive a duplicate.
    @Test func watchOriginatedSessionsStayFlaggedSoThePhoneSkipsItsHealthSave() throws {
        let profile = makeProfile()

        let watchStarted = freshStore()
        watchStarted.configure(for: profile)
        let watchWorkout = try #require(watchStarted.weeklyPlan.first)
        #expect(watchStarted.startWorkoutFromWatch(
            workoutID: watchWorkout.id.uuidString,
            startedAt: Date()
        ))
        #expect(watchStarted.activeSession?.isWatchOriginated == true)
        #expect(watchStarted.activeSession?.recordingOwner == .watch)
        let finishedFromWatch = try #require(watchStarted.finishWorkoutFromWatch(
            workoutID: watchWorkout.id.uuidString,
            endedAt: Date()
        ))
        #expect(finishedFromWatch.isWatchOriginated)
        #expect(finishedFromWatch.recordingOwner == .watch)

        let phoneStarted = freshStore()
        phoneStarted.configure(for: profile)
        let phoneWorkout = try #require(phoneStarted.weeklyPlan.first)
        #expect(phoneStarted.startWorkout(phoneWorkout))
        #expect(phoneStarted.activeSession?.isWatchOriginated == false)
        #expect(phoneStarted.activeSession?.recordingOwner == .phone)

        #expect(phoneStarted.startWorkoutFromWatch(
            workoutID: phoneWorkout.id.uuidString,
            startedAt: Date()
        ))
        #expect(phoneStarted.activeSession?.recordingOwner == .watch)
        let transferredToWatch = try #require(phoneStarted.finishActiveWorkout())
        #expect(transferredToWatch.recordingOwner == .watch)

        let phoneOnly = freshStore()
        phoneOnly.configure(for: profile)
        let phoneOnlyWorkout = try #require(phoneOnly.weeklyPlan.first)
        #expect(phoneOnly.startWorkout(phoneOnlyWorkout))
        #expect(phoneOnly.activeSession?.recordingOwner == .phone)
        let finishedOnPhone = try #require(phoneOnly.finishActiveWorkout())
        #expect(!finishedOnPhone.isWatchOriginated)
    }

    @Test func legacyPersonalRecordWithoutMetricDecodesAsWeight() throws {
        let id = UUID()
        let sessionID = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "exerciseID": "barbell-bench",
          "exerciseName": "Barbell Bench Press",
          "valueKG": 80,
          "reps": 5,
          "achievedAt": 0,
          "sessionID": "\(sessionID.uuidString)"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let record = try decoder.decode(PersonalRecord.self, from: Data(json.utf8))

        #expect(record.id == id)
        #expect(record.metric == .weight)
        #expect(record.valueKG == 80)
    }

    private func makeProfile(
        experience: FitnessExperience = .intermediate,
        goal: FitnessGoal = .strength,
        sessionsPerWeek: Int = 4,
        sessionMinutes: Int = 55,
        trainingAgeMonths: Int? = nil,
        preferredWeekdays: Set<Int>? = nil,
        measurementSystem: MeasurementSystem = .metric,
        equipment: Set<EquipmentOption> = Set(EquipmentOption.allCases),
        constraints: Set<TrainingConstraint> = [],
        baselines: [LiftBaseline] = [],
        recoveryRating: Int = 3
    ) -> UserProfileSnapshot {
        UserProfileSnapshot(
            name: "Test Athlete",
            age: 30,
            heightCM: 178,
            weightKG: 78,
            experience: experience,
            goal: goal,
            sessionsPerWeek: sessionsPerWeek,
            sessionMinutes: sessionMinutes,
            measurementSystem: measurementSystem,
            trainingAgeMonths: trainingAgeMonths,
            preferredWeekdays: preferredWeekdays,
            equipment: equipment,
            constraints: constraints,
            baselines: baselines,
            recoveryRating: recoveryRating
        )
    }

    private func progressionProfile() -> UserProfileSnapshot {
        makeProfile(
            sessionsPerWeek: 4,
            equipment: [.barbellRack, .bodyweight],
            baselines: [
                LiftBaseline(
                    exerciseID: "barbell-bench",
                    weightKG: 80,
                    reps: 6,
                    rir: 2,
                    performedAt: Date(timeIntervalSince1970: 1_700_000_000)
                ),
            ]
        )
    }

    private func workout(
        containing exerciseID: String,
        in data: WorkoutData
    ) throws -> WorkoutPrescription {
        try #require(
            data.weeklyPlan.first(where: { workout in
                workout.exercises.contains(where: { $0.exercise.id == exerciseID })
            })
        )
    }

    private func prescription(
        for exerciseID: String,
        in data: WorkoutData
    ) throws -> ExercisePrescription {
        let workout = try workout(containing: exerciseID, in: data)
        return try #require(
            workout.exercises.first(where: { $0.exercise.id == exerciseID })
        )
    }

    private func completeExercise(
        _ exerciseID: String,
        in data: WorkoutData,
        unexpectedlyHardSetCount: Int = 0
    ) throws {
        let session = try #require(data.activeSession)
        let exerciseIndex = try #require(
            session.exercises.firstIndex(where: { $0.exercise.id == exerciseID })
        )
        let sets = session.exercises[exerciseIndex].sets

        for setIndex in sets.indices {
            let set = sets[setIndex]
            let reportedRIR = setIndex < unexpectedlyHardSetCount
                ? max(set.effectiveTargetRIR - 2, 0)
                : set.effectiveTargetRIR
            data.updateReps(
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                reps: set.targetRepMax
            )
            data.updateRIR(
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                rir: reportedRIR
            )
            _ = data.toggleSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
        }
    }

    private func completeExerciseFromWatch(
        _ exerciseID: String,
        workout: WorkoutPrescription,
        in data: WorkoutData,
        startedAt: Date
    ) throws {
        let planned = try #require(
            workout.exercises.first(where: { $0.exercise.id == exerciseID })
        )
        #expect(
            data.startWorkoutFromWatch(
                workoutID: workout.id.uuidString,
                startedAt: startedAt
            )
        )

        for setNumber in 1...planned.sets {
            let completedAt = startedAt.addingTimeInterval(TimeInterval(setNumber * 60))
            let event = try #require(WatchCompletedSetEvent(dictionary: [
                "type": "completedSet",
                "eventID": UUID().uuidString,
                "workoutID": workout.id.uuidString,
                "exerciseID": exerciseID,
                "setNumber": setNumber,
                "weightKG": planned.targetWeightKG,
                "reps": planned.repMax,
                "reportedRIR": planned.effectiveTargetRIR,
                "completedAt": completedAt,
                "restSeconds": planned.restSeconds,
            ]))
            #expect(data.applyWatchCompletedSet(event))
        }

        let session = try #require(data.activeSession)
        let logged = try #require(
            session.exercises.first(where: { $0.exercise.id == exerciseID })
        )
        #expect(
            logged.sets.allSatisfy {
                $0.isComplete && $0.reportedRIR == $0.effectiveTargetRIR
            }
        )
        #expect(
            data.finishWorkoutFromWatch(
                workoutID: workout.id.uuidString,
                endedAt: startedAt.addingTimeInterval(3_600)
            ) != nil
        )
    }

    private func mirroredCoachPlan(
        from workouts: [WorkoutPrescription]
    ) -> [CoachPlanDay] {
        workouts.enumerated().map { dayIndex, workout in
            CoachPlanDay(
                title: workout.title,
                subtitle: workout.subtitle,
                dayOffset: dayIndex,
                estimatedMinutes: workout.estimatedMinutes,
                rationale: workout.rationale,
                exercises: workout.exercises.map { item in
                    CoachPlanExercise(
                        exerciseID: item.exercise.id,
                        sets: item.sets,
                        repMin: item.repMin,
                        repMax: item.repMax,
                        targetWeightKG: item.targetWeightKG,
                        restSeconds: item.restSeconds,
                        targetRIR: item.targetRIR
                    )
                }
            )
        }
    }

    private func trainingDate(daysAgo: Int, hour: Int) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let day = calendar.date(
            byAdding: .day,
            value: -daysAgo,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func freshStore() -> WorkoutData {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fitness-buddy-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        return WorkoutData(persistenceURL: url, migrateLegacy: false)
    }
}
