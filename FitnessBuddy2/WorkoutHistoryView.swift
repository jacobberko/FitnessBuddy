import SwiftUI

struct WorkoutHistoryView: View {
    @EnvironmentObject private var workoutData: WorkoutData
    @State private var sessionToDelete: WorkoutSession?

    var body: some View {
        ZStack {
            IridescentBackground()
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(workoutData.completedWorkouts) { session in
                        HStack(spacing: 8) {
                            NavigationLink {
                                WorkoutHistoryDetailView(session: session)
                            } label: {
                                SessionHistoryRow(session: session)
                            }
                            .buttonStyle(.plain)

                            Button {
                                sessionToDelete = session
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(FBPalette.magenta)
                                    .frame(width: 44, height: 58)
                                    .fitnessGlass(cornerRadius: 18, tint: FBPalette.magenta, interactive: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("SESSION ARCHIVE")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove this session?", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Delete session", role: .destructive) {
                if let sessionToDelete { workoutData.deleteSession(sessionToDelete) }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This also removes personal records earned in the session.")
        }
    }
}

struct WorkoutHistoryDetailView: View {
    let session: WorkoutSession

    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData

    var body: some View {
        ZStack {
            IridescentBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()).uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(FBPalette.lime)
                        Text(session.title.uppercased())
                            .editorialTitle(size: 39)
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 10) {
                        historyMetric("\(session.completedSetCount)", "SETS")
                        historyMetric(FitnessFormatters.duration(session.duration), "TIME")
                        historyMetric(FitnessFormatters.compactVolume(session.volume, units: userData.measurementSystem), "VOLUME")
                    }

                    if session.isLegacySummary {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "archivebox.fill").foregroundStyle(FBPalette.lime)
                            Text("This session was imported from an earlier version's history. Set-by-set data was not available then.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(FBPalette.muted)
                        }
                        .padding(18)
                        .fitnessGlass(cornerRadius: 22, tint: FBPalette.violet)
                    }

                    ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                        VStack(alignment: .leading, spacing: 13) {
                            SectionLabel(index: String(format: "%02d", index + 1), title: exercise.exercise.name, trailing: exercise.exercise.muscle.rawValue)

                            ForEach(exercise.sets) { set in
                                HStack {
                                    Text("SET \(set.setNumber)")
                                        .foregroundStyle(FBPalette.muted)
                                    Spacer()
                                    Text(FitnessFormatters.weight(set.weightKG, units: userData.measurementSystem))
                                    Text("×")
                                        .foregroundStyle(FBPalette.lime)
                                    Text("\(set.reps)")
                                }
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 42)
                                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }

                    let records = workoutData.personalRecords.filter { $0.sessionID == session.id }
                    if !records.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(index: "PR", title: "Records earned", trailing: "\(records.count)")
                            ForEach(records) { record in
                                HStack {
                                    Image(systemName: "trophy.fill").foregroundStyle(FBPalette.lime)
                                    Text(record.exerciseName.uppercased())
                                        .font(.system(size: 11, weight: .black))
                                    Spacer()
                                    Text(FitnessFormatters.weight(record.valueKG, units: userData.measurementSystem))
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                }
                                .foregroundStyle(.white)
                            }
                        }
                        .padding(17)
                        .fitnessGlass(cornerRadius: 24, tint: FBPalette.magenta)
                    }
                }
                .padding(18)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyMetric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(FBPalette.lime)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 70)
        .fitnessGlass(cornerRadius: 20, tint: FBPalette.cyan)
    }
}
