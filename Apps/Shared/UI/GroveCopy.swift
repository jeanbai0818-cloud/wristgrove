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
        case .lower: text("HRV 低于近期个人范围", "HRV below your recent range")
        case .middle: text("HRV 在近期个人范围内", "HRV within your recent range")
        case .higher: text("HRV 高于近期个人范围", "HRV above your recent range")
        case .accumulating: text("积累中", "Gathering data")
        case .insufficientVariation: text("暂不分级", "Not enough variation")
        }
    }

    static func compactBand(_ band: HRVBand) -> String {
        switch band {
        case .lower: text("偏低", "Below")
        case .middle: text("范围内", "In range")
        case .higher: text("偏高", "Above")
        case .accumulating: text("积累中", "Building")
        case .insufficientVariation: text("未分级", "Unrated")
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
        "这是 Apple Watch 采样的 SDNN HRV 相对近期个人范围的变化，可作为压力参考。HRV 也会受运动、睡眠等因素影响，不能直接测量心理压力，也不代表好坏或疾病。",
        "This compares Apple Watch SDNN HRV samples with your recent personal range as a stress reference. HRV is also affected by exercise, sleep, and other factors; it does not directly measure mental stress or diagnose a condition.")

    static let faceSetupTitle = text("把压力参考放到表盘", "Add the stress reference to your face")

    static let faceSetupLimit = text(
        "本版通过 Apple Watch 表盘组件展示健康信息。watchOS 要求你在手表上手动添加并确认位置；腕森不能静默改写当前表盘。",
        "This version shows health information through Apple Watch complications. watchOS asks you to add the complication and confirm its placement; WristGrove can’t silently change your active face.")

    static func faceSetupSteps(widgetName: String) -> [String] {
        [
            text("在 Apple Watch 上按住当前表盘，然后点“编辑”。", "On Apple Watch, touch and hold the current face, then tap Edit."),
            text("左右滑到组件位置，点你要使用的槽位。", "Swipe to the complications page and tap the slot you want to use."),
            text("滚动到“腕森”，选择“\(widgetName)”；系统会按这个槽位提供合适的样式。", "Scroll to WristGrove and choose “\(widgetName)”; watchOS offers the styles that fit this slot."),
            text("按数码表冠保存。首次添加后，腕森会按系统安排更新显示。", "Press the Digital Crown to save. After setup, watchOS schedules complication updates.")
        ]
    }

    static var faceSetupSteps: [String] {
        faceSetupSteps(widgetName: text("压力参考", "Stress Reference"))
    }

    static let samplingExplanation = text(
        "Apple Watch 按佩戴、活动和系统安排采样。没有新数据时，我们会显示真实采样时间，不会模拟测量。",
        "Apple Watch sampling depends on wear, activity and the system. We show the actual sample time and never simulate a measurement.")
}
