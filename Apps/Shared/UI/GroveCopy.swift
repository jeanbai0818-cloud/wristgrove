import Foundation
import WristGroveCore

enum GroveCopy {
    static func text(_ chinese: String, _ english: String) -> String {
        Locale.current.language.languageCode?.identifier == "zh" ? chinese : english
    }

    static func metricTitle(_ metric: MetricKind) -> String {
        switch metric {
        case .hrvSDNN: text("心率变异性", "Heart rate variability")
        case .heartRate: text("最近心率", "Latest heart rate")
        case .restingHeartRate: text("静息心率", "Resting heart rate")
        case .steps: text("今日步数", "Today's steps")
        case .sleep: text("昨夜睡眠", "Last night's sleep")
        }
    }

    static func code(_ metric: MetricKind) -> String {
        switch metric {
        case .hrvSDNN: "hrvSDNN"
        case .heartRate: "heartRate"
        case .restingHeartRate: "restingHeartRate"
        case .steps: "steps"
        case .sleep: "sleep"
        }
    }

    static func metric(from code: String) -> MetricKind? {
        switch code {
        case "hrvSDNN": .hrvSDNN
        case "heartRate": .heartRate
        case "restingHeartRate": .restingHeartRate
        case "steps": .steps
        case "sleep": .sleep
        default: nil
        }
    }

    static func symbol(_ metric: MetricKind) -> String {
        switch metric {
        case .hrvSDNN: "waveform.path.ecg"
        case .heartRate: "heart"
        case .restingHeartRate: "heart.circle"
        case .steps: "figure.walk"
        case .sleep: "moon.zzz"
        }
    }

    static func band(_ band: HRVBand) -> String {
        switch band {
        case .lower: text("较历史偏低", "Below your history")
        case .middle: text("历史中间区间", "Middle historical range")
        case .higher: text("较历史偏高", "Above your history")
        case .accumulating: text("积累中", "Gathering data")
        case .insufficientVariation: text("历史变化较少", "Limited historical variation")
        }
    }

    static func state(_ state: DataState) -> String {
        switch state {
        case .available: text("可用", "Available")
        case .noData: text("暂无数据", "No data yet")
        case .queryFailed: text("暂时无法读取", "Unable to read data")
        case .insufficientHistory: text("积累中", "Gathering data")
        case .stale: text("需要更新", "Needs an update")
        }
    }

    static func unit(_ raw: String) -> String {
        switch raw {
        case "ms": text("毫秒", "ms")
        case "bpm", "count/min": text("次/分", "bpm")
        case "steps", "count": text("步", "steps")
        case "h", "hr", "hours": text("小时", "hours")
        case "min", "minutes": text("分钟", "min")
        default: raw
        }
    }

    static func timestamp(_ date: Date?) -> String {
        guard let date else { return text("尚无采样时间", "No sample time") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static let trendExplanation = text(
        "这是 HRV 相对你个人历史的采样趋势。偏高或偏低不等于好坏，也不代表心理压力或身体恢复程度。",
        "This compares sampled HRV with your own history. Higher or lower does not mean better or worse, and does not measure mental stress or recovery.")

    static let samplingExplanation = text(
        "Apple Watch 按佩戴、活动和系统安排采样。没有新数据时，我们会显示真实采样时间，不会模拟测量。",
        "Apple Watch sampling depends on wear, activity and the system. We show the actual sample time and never simulate a measurement.")
}
