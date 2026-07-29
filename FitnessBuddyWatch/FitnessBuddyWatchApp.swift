import SwiftUI
import WatchKit

final class FitnessBuddyWatchAppDelegate: NSObject, WKApplicationDelegate {
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in
            WatchHealthWorkoutManager.shared.recoverActiveSession()
        }
    }
}

@main
struct FitnessBuddyWatchApp: App {
    @WKApplicationDelegateAdaptor(FitnessBuddyWatchAppDelegate.self) private var appDelegate
    @StateObject private var store = WatchWorkoutStore()
    @StateObject private var health = WatchHealthWorkoutManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                WatchIridescentBackdrop()

                if store.activeWorkout == nil {
                    WeeklyPlanView()
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    ActiveWorkoutView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .environmentObject(store)
            .environmentObject(health)
            .preferredColorScheme(.dark)
            .tint(WatchPalette.lime)
            .animation(.spring(response: 0.55, dampingFraction: 0.82), value: store.activeWorkout == nil)
            .task {
                if let workout = store.activeWorkout {
                    health.resumeOrStart(at: workout.startedAt)
                }
            }
            .onChange(of: store.activeWorkout?.sessionID) { oldSession, newSession in
                if oldSession == nil, let workout = store.activeWorkout {
                    health.resumeOrStart(at: workout.startedAt)
                }
            }
            .onChange(of: store.healthTermination) { _, termination in
                guard let termination else { return }
                switch termination {
                case .save(let endDate):
                    health.finish(at: endDate)
                case .discard:
                    health.discard()
                }
                store.consumeHealthTermination()
            }
        }
    }
}
