import Foundation
import Combine

// MARK: - Usage Event Model
struct UsageEvent: Codable, Equatable {
    enum Kind: String, Codable {
        case imageConversion
        case pipelineApplied
    }

    let kind: Kind
    let date: Date
}

// MARK: - Usage Tracker (in-memory; persistence handled by ViewModel)
final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    @Published private(set) var events: [UsageEvent] = []

    private init() {}

    // MARK: Recording
    func recordImageConversion(at date: Date = Date()) {
        record(.init(kind: .imageConversion, date: date))
    }

    func recordPipelineApplied(at date: Date = Date()) {
        record(.init(kind: .pipelineApplied, date: date))
    }

    private func record(_ event: UsageEvent) {
        var updated = events
        updated.append(event)
        events = updated
    }

    // MARK: Aggregations
    var totalImageConversions: Int { events.lazy.filter { $0.kind == .imageConversion }.count }
    var totalPipelineApplications: Int { events.lazy.filter { $0.kind == .pipelineApplied }.count }

    func count(kind: UsageEvent.Kind, in interval: DateInterval) -> Int {
        events.lazy.filter { $0.kind == kind && interval.contains($0.date) }.count
    }

    func count(kind: UsageEvent.Kind, onSameDayAs date: Date, calendar: Calendar = .current) -> Int {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
        let interval = DateInterval(start: dayStart, end: dayEnd)
        return count(kind: kind, in: interval)
    }

    // Persistence hook: view model will call these
    func replaceAll(_ newEvents: [UsageEvent]) {
        events = newEvents
    }
}


