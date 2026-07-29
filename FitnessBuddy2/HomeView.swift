import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case train
    case coach
    case progress
    case you

    var id: String { rawValue }
    var title: String {
        switch self {
        case .coach: "INSIGHTS"
        default: rawValue.uppercased()
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sparkles"
        case .train: "dumbbell.fill"
        case .coach: "lightbulb.fill"
        case .progress: "chart.xyaxis.line"
        case .you: "person.crop.circle"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData
    @EnvironmentObject private var watchSync: WatchSyncManager

    @State private var selection: AppTab = .today

    var body: some View {
        ZStack {
            IridescentBackground()

            TabView(selection: $selection) {
                NavigationStack { TodayView(selectedTab: $selection) }
                    .tag(AppTab.today)
                    .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.systemImage) }

                NavigationStack { TrainView() }
                    .tag(AppTab.train)
                    .tabItem { Label(AppTab.train.title, systemImage: AppTab.train.systemImage) }

                NavigationStack { InsightsView() }
                    .tag(AppTab.coach)
                    .tabItem { Label(AppTab.coach.title, systemImage: AppTab.coach.systemImage) }

                NavigationStack { ProgressDashboardView() }
                    .tag(AppTab.progress)
                    .tabItem { Label(AppTab.progress.title, systemImage: AppTab.progress.systemImage) }

                NavigationStack { YouView() }
                    .tag(AppTab.you)
                    .tabItem { Label(AppTab.you.title, systemImage: AppTab.you.systemImage) }
            }
            .tint(FBPalette.lime)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(FBPalette.black.opacity(0.92), for: .tabBar)
        }
        .sensoryFeedback(.selection, trigger: selection)
        .fullScreenCover(item: $workoutData.activeSession) { _ in
            WorkoutDetailView()
                .environmentObject(userData)
                .environmentObject(workoutData)
        }
        .onAppear {
            workoutData.configure(for: userData.snapshot)
            watchSync.sync(plan: workoutData.weeklyPlan)
        }
        .onChange(of: userData.snapshot) { _, profile in
            workoutData.configure(for: profile)
            watchSync.sync(plan: workoutData.weeklyPlan)
        }
    }
}

struct ScreenHeader: View {
    let kicker: String
    let title: String
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(kicker.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(FBPalette.lime)
                Text(title.uppercased())
                    .font(.system(size: 36, weight: .black))
                    .fontWidth(.expanded)
                    .tracking(-1.7)
                    .foregroundStyle(.white)
            }
            Spacer()
            if let actionIcon, let action {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .fitnessGlass(cornerRadius: 23, tint: FBPalette.cyan, interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(UserData())
            .environmentObject(WorkoutData())
            .environmentObject(HealthKitManager())
            .environmentObject(WorkoutLiveActivityManager())
            .environmentObject(WatchSyncManager())
    }
}
