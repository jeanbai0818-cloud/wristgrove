import SwiftUI
import WristGroveCore

struct MetricTile: View {
    let metric: MetricKind
    let reading: MetricReading?
    var isDemo = false
    var showsTime = true

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(GroveCopy.metricTitle(metric), systemImage: GroveCopy.symbol(metric))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(HealthPresentation.value(reading))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                if let reading, HealthPresentation.hasValue(reading) {
                    Text(GroveCopy.unit(reading.unit)).font(.caption)
                }
            }
            if let reading, reading.state != .available {
                Text(GroveCopy.state(reading.state)).font(.caption)
            }
            if reading?.sourceID != nil {
                Text(isDemo
                     ? GroveCopy.text("来源：本地演示数据", "Source: local demo data")
                     : GroveCopy.text("来源：Apple 健康", "Source: Apple Health"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsTime {
                Text(GroveCopy.timestamp(reading?.sampledAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct GroveTrendCard: View {
    let snapshot: HealthSnapshot?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 12) {
            Label(GroveCopy.text("表盘压力参考 · SDNN HRV", "Watch-face stress reference · SDNN HRV"), systemImage: "waveform.path.ecg")
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.secondary)
            Text(HealthPresentation.trendTitle(snapshot))
                .font(compact ? .headline : .title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let trend = snapshot?.trend, HealthPresentation.trendIsCurrent(snapshot) {
                Text(GroveCopy.text("截至", "Through") + " \(trend.cutoffHour):00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !compact {
                    Text(GroveCopy.text("今日窗口样本", "Samples in today's window") + " \(trend.sampleCount) · "
                         + GroveCopy.text("历史有效日", "Historical days") + " \(trend.effectiveDays)/28")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !compact {
                Text(GroveCopy.trendExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
