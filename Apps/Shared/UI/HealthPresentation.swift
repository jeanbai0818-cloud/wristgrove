import Foundation
import WristGroveCore

enum HealthPresentation {
    static func value(_ reading: MetricReading?) -> String {
        guard let reading else { return GroveCopy.text("暂无数据", "No data") }
        guard let value = reading.value, value.isFinite,
              value > 0 || (reading.metric == .steps && value == 0) else {
            return GroveCopy.state(reading.state)
        }
        let precision = reading.metric == .steps ? 0 : 1
        return value.formatted(.number.precision(.fractionLength(0...precision)))
    }

    static func hasValue(_ reading: MetricReading?) -> Bool {
        guard let reading, let value = reading.value, value.isFinite else { return false }
        return value > 0 || (reading.metric == .steps && value == 0)
    }

    static func trendIsCurrent(_ snapshot: HealthSnapshot?, at now: Date = Date()) -> Bool {
        guard let snapshot, let trend = snapshot.trend,
              snapshot.timeZoneIdentifier == TimeZone.current.identifier else { return false }
        let calendar = Calendar.current
        return calendar.isDate(trend.assessedAt, inSameDayAs: now)
            && trend.cutoffHour == calendar.component(.hour, from: now)
    }

    static func trendTitle(_ snapshot: HealthSnapshot?, at now: Date = Date()) -> String {
        guard let snapshot else { return GroveCopy.text("暂无数据", "No data yet") }
        guard trendIsCurrent(snapshot, at: now), let trend = snapshot.trend else {
            return GroveCopy.text("需要更新", "Needs an update")
        }
        return GroveCopy.band(trend.band)
    }

    static func compactTrendTitle(_ snapshot: HealthSnapshot?, at now: Date = Date()) -> String {
        guard let snapshot else { return GroveCopy.text("无数据", "No data") }
        guard trendIsCurrent(snapshot, at: now), let trend = snapshot.trend else {
            return GroveCopy.text("更新", "Update")
        }
        return GroveCopy.compactBand(trend.band)
    }

    static func metricURL(_ metric: MetricKind) -> URL {
        URL(string: "wristgrove://metric/\(GroveCopy.code(metric))")!
    }
}
