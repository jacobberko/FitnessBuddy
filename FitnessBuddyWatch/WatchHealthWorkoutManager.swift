import Foundation
import HealthKit

@MainActor
final class WatchHealthWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchHealthWorkoutManager()

    @Published private(set) var isAuthorized = false
    @Published private(set) var isActive = false
    @Published private(set) var heartRate = 0.0
    @Published private(set) var activeEnergyKCal = 0.0
    @Published private(set) var lastError: String?

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var isRecovering = false
    private var isStarting = false
    private var pendingStartDate: Date?
    private var pendingTermination: WatchWorkoutTermination?

    /// Recovers HealthKit's live builder after a relaunch. If there is no
    /// recoverable builder, starts a new one for the restored app workout.
    func resumeOrStart(at startDate: Date) {
        guard workoutSession == nil else { return }
        pendingStartDate = startDate
        recoverActiveSession()
    }

    /// Called by `WKApplicationDelegate.handleActiveWorkoutRecovery`.
    func recoverActiveSession() {
        guard workoutSession == nil, !isRecovering, !isStarting else { return }
        isRecovering = true
        healthStore.recoverActiveWorkoutSession { [weak self] session, error in
            Task { @MainActor in
                guard let self else { return }
                self.isRecovering = false
                if let session {
                    self.attachRecoveredSession(session)
                    self.pendingStartDate = nil
                    self.lastError = nil
                    self.applyPendingTerminationIfNeeded()
                } else if let startDate = self.pendingStartDate {
                    self.pendingStartDate = nil
                    self.startNewSession(at: startDate)
                } else if let error {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func startNewSession(at startDate: Date) {
        guard workoutSession == nil, !isStarting else { return }
        isStarting = true
        Task {
            do {
                try await authorizeIfNeeded()

                let configuration = HKWorkoutConfiguration()
                configuration.activityType = .traditionalStrengthTraining
                configuration.locationType = .indoor

                let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(
                    healthStore: healthStore,
                    workoutConfiguration: configuration
                )
                session.delegate = self
                builder.delegate = self
                workoutSession = session
                workoutBuilder = builder

                session.startActivity(with: startDate)
                try await beginCollection(builder, at: startDate)
                isActive = true
                lastError = nil
                isStarting = false
                applyPendingTerminationIfNeeded()
            } catch {
                lastError = error.localizedDescription
                isActive = false
                isStarting = false
                reset()
            }
        }
    }

    func finish(at endDate: Date = Date()) {
        guard let session = workoutSession, let builder = workoutBuilder else {
            pendingTermination = .save(endDate: endDate)
            return
        }
        pendingTermination = nil
        session.end()
        Task {
            do {
                try await endCollection(builder, at: endDate)
                _ = try await finishWorkout(builder)
                reset()
            } catch {
                lastError = error.localizedDescription
                reset()
            }
        }
    }

    func discard() {
        guard let session = workoutSession, let builder = workoutBuilder else {
            pendingTermination = .discard
            return
        }
        pendingTermination = nil
        session.end()
        builder.discardWorkout()
        reset()
    }

    private func authorizeIfNeeded() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw WatchHealthError.unavailable }
        let workout = HKObjectType.workoutType()
        var read = Set<HKObjectType>()
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) { read.insert(heartRate) }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(energy) }
        try await healthStore.requestAuthorization(toShare: [workout], read: read)
        isAuthorized = healthStore.authorizationStatus(for: workout) == .sharingAuthorized
    }

    private func refreshStatistics() {
        guard let builder = workoutBuilder else { return }
        if let type = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let quantity = builder.statistics(for: type)?.mostRecentQuantity() {
            heartRate = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let quantity = builder.statistics(for: type)?.sumQuantity() {
            activeEnergyKCal = quantity.doubleValue(for: .kilocalorie())
        }
    }

    private func reset() {
        workoutSession = nil
        workoutBuilder = nil
        isActive = false
        heartRate = 0
        activeEnergyKCal = 0
    }

    private func attachRecoveredSession(_ session: HKWorkoutSession) {
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: session.workoutConfiguration
        )
        session.delegate = self
        builder.delegate = self
        workoutSession = session
        workoutBuilder = builder
        isActive = session.state == .running
        refreshStatistics()
    }

    private func applyPendingTerminationIfNeeded() {
        guard let termination = pendingTermination else { return }
        pendingTermination = nil
        switch termination {
        case .save(let endDate):
            finish(at: endDate)
        case .discard:
            discard()
        }
    }

    private func beginCollection(_ builder: HKLiveWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: WatchHealthError.operationFailed) }
            }
        }
    }

    private func endCollection(_ builder: HKLiveWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: date) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: WatchHealthError.operationFailed) }
            }
        }
    }

    private func finishWorkout(_ builder: HKLiveWorkoutBuilder) async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { continuation in
            builder.finishWorkout { workout, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: workout) }
            }
        }
    }

    private enum WatchHealthError: LocalizedError {
        case unavailable
        case operationFailed

        var errorDescription: String? {
            switch self {
            case .unavailable: "HealthKit is not available on this Apple Watch."
            case .operationFailed: "The workout could not be recorded."
            }
        }
    }
}

extension WatchHealthWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            self.isActive = toState == .running
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.lastError = message
            self.isActive = false
        }
    }
}

extension WatchHealthWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in self.refreshStatistics() }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
}
