import Foundation

struct DailyBPMRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    var bpmValues: [Int]

    var averageBPM: Int {
        guard !bpmValues.isEmpty else { return 0 }
        return bpmValues.reduce(0, +) / bpmValues.count
    }
}

enum BPMStorage {
    private static let key = "dailyBPMRecords"

    static func loadDaily() -> [DailyBPMRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DailyBPMRecord].self, from: data) else {
            return []
        }
        return decoded
    }

    static func saveDaily(_ records: [DailyBPMRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func appendSession(bpm: Int, at date: Date = Date()) {
        var records = loadDaily()
        let today = startOfDay(for: date)

        if let index = records.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            records[index].bpmValues.append(bpm)
        } else {
            let new = DailyBPMRecord(id: UUID(), date: today, bpmValues: [bpm])
            records.append(new)
        }

        saveDaily(records)
    }

    static func getAllDailyAverages() -> [DailyBPMRecord] {
        loadDaily().sorted { $0.date < $1.date }
    }

    static func getWeeklyAverage() -> Int {
        let all = loadDaily()
        let last7 = all.suffix(7)
        guard !last7.isEmpty else { return 0 }

        let sum = last7.map { $0.averageBPM }.reduce(0, +)
        return sum / last7.count
    }
}

