import SwiftUI

@main
struct FitnessBuddy2App: App {
    @StateObject private var userData = UserData()
    @StateObject private var workoutData = WorkoutData()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var liveActivity = WorkoutLiveActivityManager()
    @StateObject private var watchSync = WatchSyncManager()

    init() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithTransparentBackground()
        navigation.backgroundColor = .clear
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation

        UITabBar.appearance().isTranslucent = true
    }

    var body: some Scene {
        WindowGroup {
            RootRouter()
                .environmentObject(userData)
                .environmentObject(workoutData)
                .environmentObject(healthKit)
                .environmentObject(liveActivity)
                .environmentObject(watchSync)
                .preferredColorScheme(.dark)
                .tint(FBPalette.lime)
                .task {
                    watchSync.onEvent = { event in
                        switch event {
                        case .completedSet(let completedSet):
                            if workoutData.applyWatchCompletedSet(completedSet) {
                                refreshLiveActivity()
                            }
                        case .workoutStarted(let workoutID, let startedAt):
                            if workoutData.startWorkoutFromWatch(workoutID: workoutID, startedAt: startedAt) {
                                refreshLiveActivity()
                            }
                        case .workoutCompleted(let completion):
                            guard workoutData.startWorkoutFromWatch(
                                workoutID: completion.workoutID,
                                startedAt: completion.startedAt
                            ) else { return }

                            for completedSet in completion.completedSets {
                                guard workoutData.applyWatchCompletedSet(completedSet) else {
                                    refreshLiveActivity()
                                    return
                                }
                            }

                            guard let session = workoutData.finishWorkoutFromWatch(
                                workoutID: completion.workoutID,
                                endedAt: completion.endedAt
                            ) else { return }
                            liveActivity.end(session: session)
                            // The Watch already saved this workout to Health via its own
                            // HKWorkoutSession, so the phone must not write a duplicate.
                            if !session.isWatchOriginated {
                                Task { _ = await healthKit.save(session) }
                            }
                        case .workoutDiscarded(let workoutID, _):
                            if workoutData.discardWorkoutFromWatch(workoutID: workoutID) {
                                liveActivity.cancel()
                            }
                        case .requestWeeklyPlan:
                            watchSync.sync(plan: workoutData.weeklyPlan)
                        }
                    }
                    if userData.healthKitEnabled {
                        await healthKit.restoreAuthorizationState()
                    }
                    if userData.hasCompletedOnboarding {
                        workoutData.configure(for: userData.snapshot)
                        watchSync.sync(plan: workoutData.weeklyPlan)
                    }
                    liveActivity.recover(
                        session: workoutData.activeSession,
                        exerciseIndex: workoutData.activeExerciseIndex,
                        restEndsAt: workoutData.restEndsAt
                    )
                }
                .onOpenURL { url in
                    guard url.scheme == "berko-fitnessbuddy2", url.host == "workout" else { return }
                    workoutData.openWorkoutDeepLink(sessionID: url.lastPathComponent)
                }
        }
    }

    private func refreshLiveActivity() {
        liveActivity.recover(
            session: workoutData.activeSession,
            exerciseIndex: workoutData.activeExerciseIndex,
            restEndsAt: workoutData.restEndsAt
        )
    }
}

private struct RootRouter: View {
    @EnvironmentObject private var userData: UserData

    var body: some View {
        ZStack {
            if userData.hasCompletedOnboarding {
                HomeView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.65, dampingFraction: 0.88), value: userData.hasCompletedOnboarding)
    }
}
