import SwiftUI
import Charts

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var dailyRecords: [DailyBPMRecord] = []
    @State private var weeklyAverage: Int = 0

    private let accent = Color(red: 46/255, green: 196/255, blue: 182/255)

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    chartCard

                    HStack {
                        Text("Daily Records")
                            .font(.title3.bold())
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    VStack(spacing: 10) {
                        if dailyRecords.isEmpty {
                            emptyStateCard
                        } else {
                            ForEach(dailyRecords) { record in
                                dailyRowCard(record)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    weeklySummaryCard

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .top) {
            topBar
        }
        .onAppear {
            dailyRecords = BPMStorage.getAllDailyAverages().sorted { $0.date > $1.date } // en yeni üstte
            weeklyAverage = BPMStorage.getWeeklyAverage()
        }
    }

    private var topBar: some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.80)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }

                Spacer()

                Text("Historical Data")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .padding(.top, 10)
        }
        .frame(height: 64)
    }

    private var chartCard: some View {
        VStack(spacing: 12) {
            Text("7-Day Average BPM")
                .font(.headline)
                .foregroundColor(.black)

            if last7ChartData.isEmpty {
                Text("Insufficient data to display the chart.")
                    .foregroundColor(.gray)
                    .padding(.vertical, 24)
            } else {
                Chart(last7ChartData) { item in
                    LineMark(
                        x: .value("Day", item.dayLabel),
                        y: .value("BPM", item.bpm)
                    )
                    PointMark(
                        x: .value("Day", item.dayLabel),
                        y: .value("BPM", item.bpm)
                    )
                }
                .chartYScale(domain: 40...180)
                .frame(height: 180)
                .padding(.horizontal, 4)
            }

            HStack(spacing: 10) {
                Text("Visual Average")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.gray)

                Spacer()

                Text("\(visualAverage) BPM")
                    .font(.title3.bold())
                    .foregroundColor(accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(accent)

            Text("No data yet")
                .font(.headline)
                .foregroundColor(.black)

            Text("Complete a measurement to view your daily averages.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func dailyRowCard(_ record: DailyBPMRecord) -> some View {
        HStack(spacing: 12) {
            Text(formattedDate(record.date))
                .font(.headline)
                .foregroundColor(.black)

            Spacer()

            Text("\(record.averageBPM) BPM")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(accent)
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    private var weeklySummaryCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Average BPM")
                    .font(.headline)
                    .foregroundColor(.black)

                Text("7-Day Average")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("\(weeklyAverage) BPM")
                .font(.title2.bold())
                .foregroundColor(accent)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private struct ChartItem: Identifiable {
        let id = UUID()
        let dayLabel: String
        let bpm: Int
        let date: Date
    }

    private var last7ChartData: [ChartItem] {
        let sorted = BPMStorage.getAllDailyAverages().sorted { $0.date > $1.date }
        let last7 = Array(sorted.prefix(7)).reversed()

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.dateFormat = "EEE" 

        return last7.map { record in
            ChartItem(dayLabel: fmt.string(from: record.date).capitalized, bpm: record.averageBPM, date: record.date)
        }
    }

    private var visualAverage: Int {
        guard !last7ChartData.isEmpty else { return 0 }
        let sum = last7ChartData.map { $0.bpm }.reduce(0, +)
        return sum / last7ChartData.count
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }
}

