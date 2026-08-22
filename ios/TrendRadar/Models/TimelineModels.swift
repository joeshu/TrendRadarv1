import Foundation

struct TimelineAction: Equatable, Sendable {
    var collect: Bool
    var analyze: Bool
    var push: Bool
    var reportMode: ReportType
    var aiMode: ReportType
    var onceAnalyze: Bool
    var oncePush: Bool

    static let passive = TimelineAction(collect: true, analyze: false, push: false, reportMode: .current, aiMode: .current, onceAnalyze: true, oncePush: true)
}

struct TimelinePeriod: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let startMinutes: Int
    let endMinutes: Int
    let action: TimelineAction

    func contains(minute: Int) -> Bool {
        if startMinutes <= endMinutes {
            return minute >= startMinutes && minute < endMinutes
        }
        return minute >= startMinutes || minute < endMinutes
    }
}

struct TimelinePreset: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let description: String
    let defaultAction: TimelineAction
    let periods: [TimelinePeriod]

    func action(at date: Date, calendar: Calendar = .current) -> TimelineAction {
        match(at: date, calendar: calendar).action
    }

    func match(at date: Date, calendar: Calendar = .current) -> (periodID: String?, action: TimelineAction) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if let period = periods.first(where: { $0.contains(minute: minute) }) {
            return (period.id, period.action)
        }
        return (nil, defaultAction)
    }
}

extension Calendar {
    static func trendRadar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar
    }
}

struct TimelineExecutionStore: @unchecked Sendable {
    private let defaults = UserDefaults.standard
    private let key = "trendradar.timeline.executions"

    func claim(presetID: String, periodID: String?, action: TimelineAction, at date: Date = Date(), calendar: Calendar = .current) -> TimelineAction {
        let dateKey = executionDateKey(periodID: periodID, at: date, calendar: calendar)
        var executions = defaults.stringArray(forKey: key) ?? []
        executions = executions.filter { marker in
            marker.split(separator: "|").dropFirst(2).first.map(String.init) == dateKey
        }
        var result = action
        let prefix = "\(presetID)|\(periodID ?? "default")|\(dateKey)|"
        if action.onceAnalyze {
            let marker = prefix + "analyze"
            result.analyze = !executions.contains(marker) && action.analyze
            if result.analyze { executions.append(marker) }
        }
        if action.oncePush {
            let marker = prefix + "push"
            result.push = !executions.contains(marker) && action.push
            if result.push { executions.append(marker) }
        }
        defaults.set(executions, forKey: key)
        return result
    }

    private func executionDateKey(periodID: String?, at date: Date, calendar: Calendar) -> String {
        var executionDate = date
        if let periodID, periodID != "default" {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            let preset = TimelineCatalog.presets.flatMap(\.periods).first { $0.id == periodID }
            if let preset, preset.startMinutes > preset.endMinutes, minute < preset.endMinutes {
                executionDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            }
        }
        let components = calendar.dateComponents([.year, .month, .day], from: executionDate)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

enum TimelineCatalog {
    static let presets: [TimelinePreset] = [
        TimelinePreset(id: "always_on", name: "全天监控", description: "全天采集，有新增内容时提醒。", defaultAction: TimelineAction(collect: true, analyze: false, push: true, reportMode: .incremental, aiMode: .current, onceAnalyze: false, oncePush: false), periods: []),
        TimelinePreset(id: "morning_evening", name: "早晚汇总", description: "全天关注，晚间生成当日汇总。", defaultAction: TimelineAction(collect: true, analyze: true, push: true, reportMode: .current, aiMode: .current, onceAnalyze: false, oncePush: false), periods: [period(id: "evening_summary", name: "晚间汇总", start: "20:00", end: "22:00", action: TimelineAction(collect: true, analyze: true, push: true, reportMode: .daily, aiMode: .daily, onceAnalyze: true, oncePush: true))]),
        TimelinePreset(id: "office_hours", name: "办公时间", description: "工作日分段关注，午间轻量更新。", defaultAction: TimelineAction(collect: true, analyze: false, push: false, reportMode: .current, aiMode: .current, onceAnalyze: true, oncePush: true), periods: [period(id: "morning_briefing", name: "到岗速览", start: "09:00", end: "11:00", action: TimelineAction(collect: true, analyze: true, push: true, reportMode: .current, aiMode: .current, onceAnalyze: true, oncePush: true)), period(id: "noon_update", name: "午间热点", start: "13:00", end: "15:00", action: TimelineAction(collect: true, analyze: false, push: true, reportMode: .current, aiMode: .current, onceAnalyze: true, oncePush: true)), period(id: "closing_summary", name: "收工汇总", start: "17:00", end: "19:00", action: TimelineAction(collect: true, analyze: true, push: true, reportMode: .daily, aiMode: .daily, onceAnalyze: true, oncePush: true))]),
        TimelinePreset(id: "night_owl", name: "夜猫子模式", description: "午后速览，深夜生成全天汇总。", defaultAction: TimelineAction(collect: true, analyze: false, push: false, reportMode: .current, aiMode: .current, onceAnalyze: true, oncePush: true), periods: [period(id: "afternoon_peek", name: "午后速览", start: "15:00", end: "17:00", action: TimelineAction(collect: true, analyze: true, push: true, reportMode: .current, aiMode: .current, onceAnalyze: true, oncePush: true)), period(id: "late_night", name: "深夜汇总", start: "22:00", end: "01:00", action: TimelineAction(collect: true, analyze: true, push: true, reportMode: .daily, aiMode: .daily, onceAnalyze: true, oncePush: true))])
    ]

    static func preset(for id: String) -> TimelinePreset {
        presets.first { $0.id == id } ?? presets[3]
    }

    private static func period(id: String, name: String, start: String, end: String, action: TimelineAction) -> TimelinePeriod {
        TimelinePeriod(id: id, name: name, startMinutes: minutes(start), endMinutes: minutes(end), action: action)
    }

    private static func minutes(_ value: String) -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return (parts.first ?? 0) * 60 + (parts.dropFirst().first ?? 0)
    }
}
