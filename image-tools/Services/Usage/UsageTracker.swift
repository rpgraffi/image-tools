import Foundation
import Combine


final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    @Published private(set) var events: [UsageEventModel] = []

    private init() {}

    // MARK: Recording
    func recordImageConversion(at date: Date = Date()) {
        record(.init(kind: .imageConversion, date: date))
    }

    func recordPipelineApplied(at date: Date = Date()) {
        record(.init(kind: .pipelineApplied, date: date))
    }

    private func record(_ event: UsageEventModel) {
        var updated = events
        updated.append(event)
        events = updated
    }

    // MARK: Aggregations
    var totalImageConversions: Int { events.lazy.filter { $0.kind == .imageConversion }.count }
    var totalPipelineApplications: Int { events.lazy.filter { $0.kind == .pipelineApplied }.count }

    func count(kind: UsageEventModel.Kind, in interval: DateInterval) -> Int {
        events.lazy.filter { $0.kind == kind && interval.contains($0.date) }.count
    }

    func count(kind: UsageEventModel.Kind, onSameDayAs date: Date, calendar: Calendar = .current) -> Int {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
        let interval = DateInterval(start: dayStart, end: dayEnd)
        return count(kind: kind, in: interval)
    }

    // Persistence hook: view model will call these
    func replaceAll(_ newEvents: [UsageEventModel]) {
        events = newEvents
    }
}


