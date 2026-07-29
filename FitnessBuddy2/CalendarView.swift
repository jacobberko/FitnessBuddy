import Charts
import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData

    @State private var chartDays = 7
    @State private var chartAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                ScreenHeader(kicker: "Performance archive", title: "Progress")
                    .padding(.top, 10)

                scoreCard
                trainingChart
                recoverySection
                recordsSection
                historySection
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 118)
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { chartAppeared = true }
        }
    }

    private var scoreCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: chartAppeared ? weeklyAdherence : 0)
                    .stroke(FBPalette.iridescentAngular, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(Int(weeklyAdherence * 100))")
                        .font(.system(size: 29, weight: .black, design: .monospaced))
                    Text("SCORE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(FBPalette.lime)
                }
                .foregroundStyle(.white)
            }
            .frame(width: 115, height: 115)

            VStack(alignment: .leading, spacing: 8) {
                Text("WEEK / SIGNAL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(FBPalette.lime)
                Text(scoreHeadline)
                    .font(.system(size: 23, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.white)
                Text("\(workoutData.weeklyCompletedCount) of \(userData.sessionsPerWeek) sessions complete · \(workoutData.personalRecords.filter { Calendar.current.isDate($0.achievedAt, equalTo: Date(), toGranularity: .weekOfYear) }.count) new PRs")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .fitnessGlass(cornerRadius: 30, tint: FBPalette.lime)
    }

    private var trainingChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                SectionLabel(index: "01", title: "Training load")
                Picker("Range", selection: $chartDays) {
                    Text("7D").tag(7)
                    Text("30D").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 104)
            }

            Chart(workoutData.volumePoints(days: chartDays)) { point in
                AreaMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Volume", displayVolume(point.volumeKG))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [FBPalette.lime.opacity(0.42), FBPalette.violet.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Volume", displayVolume(point.volumeKG))
                )
                .foregroundStyle(FBPalette.iridescent)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Volume", displayVolume(point.volumeKG))
                )
                .foregroundStyle(FBPalette.lime)
                .symbolSize(point.volumeKG > 0 ? 28 : 0)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: chartDays == 7 ? 7 : 6)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(FBPalette.muted)
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.045))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel()
                        .foregroundStyle(FBPalette.muted)
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                }
            }
            .frame(height: 210)

            HStack {
                Text("TOTAL / \(FitnessFormatters.compactVolume(workoutData.volumePoints(days: chartDays).reduce(0) { $0 + $1.volumeKG }, units: userData.measurementSystem)) \(userData.measurementSystem.weightUnit.uppercased())")
                Spacer()
                Text("LIVE FROM SET LOGS")
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(FBPalette.muted)
        }
        .padding(18)
        .fitnessGlass(cornerRadius: 28, tint: FBPalette.cyan)
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(index: "02", title: "Muscle recovery", trailing: "Estimated")
            ForEach(MuscleGroup.allCases.filter { $0 != MuscleGroup.conditioning }, id: \.self) { muscle in
                let value = workoutData.recovery(for: muscle)
                HStack(spacing: 12) {
                    Image(systemName: muscle.systemImage)
                        .foregroundStyle(value > 0.7 ? FBPalette.lime : FBPalette.magenta)
                        .frame(width: 24)
                    Text(muscle.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 80, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule()
                                .fill(value > 0.7 ? AnyShapeStyle(FBPalette.lime) : AnyShapeStyle(FBPalette.iridescent))
                                .frame(width: chartAppeared ? max(0, proxy.size.width * value) : 0)
                        }
                    }
                    .frame(height: 7)
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(FBPalette.muted)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var recordsSection: some View {
        if !workoutData.personalRecords.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                SectionLabel(index: "03", title: "Personal records", trailing: "\(workoutData.personalRecords.count) total")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(workoutData.personalRecords.prefix(8))) { record in
                            PRCard(record: record, units: userData.measurementSystem)
                        }
                    }
                }
                .contentMargins(.horizontal, 1)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(index: "04", title: "Recent sessions", trailing: "Archive")
            ForEach(workoutData.completedWorkouts.prefix(4)) { session in
                NavigationLink {
                    WorkoutHistoryDetailView(session: session)
                } label: {
                    SessionHistoryRow(session: session)
                }
                .buttonStyle(.plain)
            }
            if workoutData.completedWorkouts.isEmpty {
                Text("Complete your first workout to begin the archive.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .fitnessGlass(cornerRadius: 22, tint: FBPalette.violet)
            } else {
                NavigationLink("VIEW ALL SESSIONS") { WorkoutHistoryView() }
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(FBPalette.lime)
                    .padding(.top, 3)
            }
        }
    }

    private var weeklyAdherence: Double {
        min(Double(workoutData.weeklyCompletedCount) / Double(max(userData.sessionsPerWeek, 1)), 1)
    }

    private var scoreHeadline: String {
        switch weeklyAdherence {
        case 0.8...: "HIGH OUTPUT"
        case 0.45...: "BUILDING MOMENTUM"
        default: "WEEK IN MOTION"
        }
    }

    private func displayVolume(_ kilograms: Double) -> Double {
        userData.measurementSystem == .imperial ? kilograms * 2.204_622_621_8 : kilograms
    }
}

private struct PRCard: View {
    let record: PersonalRecord
    let units: MeasurementSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "trophy.fill").foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(FBPalette.iridescent, in: Circle())
                Spacer()
                Text(record.achievedAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.muted)
            }
            Text(record.exerciseName.uppercased())
                .font(.system(size: 12, weight: .black))
                .fontWidth(.expanded)
                .foregroundStyle(.white)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(FitnessFormatters.weight(record.valueKG, units: units, includeUnit: false))
                    .font(.system(size: 27, weight: .black, design: .monospaced))
                Text(units.weightUnit.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.lime)
            }
            .foregroundStyle(.white)
        }
        .padding(16)
        .frame(width: 180, height: 168)
        .fitnessGlass(cornerRadius: 25, tint: FBPalette.magenta)
    }
}

struct SessionHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(session.startedAt.formatted(.dateTime.day()))
                    .font(.system(size: 19, weight: .black, design: .monospaced))
                Text(session.startedAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.lime)
            }
            .foregroundStyle(.white)
            .frame(width: 48, height: 53)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text(session.title.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.white)
                Text(session.isLegacySummary ? "IMPORTED SUMMARY" : "\(session.completedSetCount) SETS  /  \(FitnessFormatters.duration(session.duration))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(FBPalette.muted)
        }
        .padding(13)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(FBPalette.hairline, lineWidth: 0.7) }
    }
}

// Retains the original sheet type while routing to the rebuilt progress experience.
struct CalendarView: View {
    var body: some View { ProgressDashboardView() }
}
