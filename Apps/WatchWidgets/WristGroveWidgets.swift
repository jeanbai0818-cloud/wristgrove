import SwiftUI
import WidgetKit
import WristGroveCore

private enum WidgetMetric: String {
    case trend, hrv, steps

    var title: String {
        switch self {
        case .trend: GroveCopy.text("HRV 趋势", "HRV trend")
        case .hrv: GroveCopy.text("最近 HRV", "Latest HRV")
        case .steps: GroveCopy.text("今日步数", "Today's steps")
        }
    }

    var metric: MetricKind { self == .steps ? .steps : .hrvSDNN }

    var destination: MetricKind { metric }
}

private struct GroveWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: HealthSnapshot?
    let metric: WidgetMetric
}

private struct GroveWidgetProvider: TimelineProvider {
    let metric: WidgetMetric

    func placeholder(in context: Context) -> GroveWidgetEntry {
        GroveWidgetEntry(date: Date(), snapshot: nil, metric: metric)
    }

    func getSnapshot(in context: Context, completion: @escaping (GroveWidgetEntry) -> Void) {
        let now = Date()
        completion(GroveWidgetEntry(date: now, snapshot: SnapshotStore().loadForWidget(at: now), metric: metric))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GroveWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = SnapshotStore().loadForWidget(at: now)
        let entry = GroveWidgetEntry(date: now, snapshot: snapshot, metric: metric)
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60 * 60))))
    }
}

private struct GroveWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: GroveWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            case .accessoryInline:
                inline
            default:
                rectangular
            }
        }
        .widgetURL(HealthPresentation.metricURL(entry.metric.destination))
        .containerBackground(.background, for: .widget)
        .accessibilityElement(children: .combine)
    }

    private var circular: some View {
        VStack(spacing: 3) {
            Image(systemName: entry.metric == .steps ? "figure.walk" : "leaf")
                .font(.caption)
                .foregroundStyle(scheme == .dark ? GroveStyle.sage : GroveStyle.forest)
            if entry.metric == .trend {
                Text(HealthPresentation.trendTitle(entry.snapshot, at: entry.date))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                let reading = entry.snapshot?.reading(for: entry.metric.metric)
                Text(HealthPresentation.value(reading))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(entry.snapshot?.isDemo == true
                     ? GroveCopy.text("演示", "DEMO")
                     : (entry.metric == .steps ? GroveCopy.text("步", "steps") : "ms"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                if let sampledAt = reading?.sampledAt {
                    Text(sampledAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                if let reading, reading.value != nil, reading.state != .available {
                    Text(GroveCopy.state(reading.state))
                        .font(.system(size: 7))
                        .lineLimit(1)
                }
            }
            if entry.metric == .trend, entry.snapshot?.isDemo == true {
                Text(GroveCopy.text("演示", "DEMO"))
                    .font(.system(size: 7, weight: .bold))
                    .accessibilityLabel(GroveCopy.text("演示数据", "Demo data"))
            }
        }
        .foregroundStyle(GroveStyle.ink(scheme))
        .padding(3)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: entry.metric == .steps ? "figure.walk" : "leaf")
                    .foregroundStyle(scheme == .dark ? GroveStyle.sage : GroveStyle.forest)
                Text(entry.metric.title).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            if entry.metric == .trend {
                Text(HealthPresentation.trendTitle(entry.snapshot, at: entry.date))
                    .font(.headline)
                    .lineLimit(1)
                if let trend = entry.snapshot?.trend, HealthPresentation.trendIsCurrent(entry.snapshot, at: entry.date) {
                    Text(GroveCopy.text("截至", "Through") + " \(trend.cutoffHour):00 · \(trend.effectiveDays)/28")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                let reading = entry.snapshot?.reading(for: entry.metric.metric)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(HealthPresentation.value(reading))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text(GroveCopy.unit(reading?.unit ?? (entry.metric == .steps ? "steps" : "ms")))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(GroveCopy.timestamp(reading?.sampledAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let reading, reading.value != nil, reading.state != .available {
                    Text(GroveCopy.state(reading.state))
                        .font(.caption2)
                }
            }
            if entry.snapshot?.isDemo == true {
                    Text(GroveCopy.text("演示数据", "Demo data"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(scheme == .dark ? GroveStyle.sage : GroveStyle.forest)
            }
        }
        .foregroundStyle(GroveStyle.ink(scheme))
        .padding(.horizontal, 3)
    }

    private var inline: some View {
        let reading = entry.snapshot?.reading(for: entry.metric.metric)
        if entry.metric == .trend {
            Text((entry.snapshot?.isDemo == true ? GroveCopy.text("演示 · ", "DEMO · ") : "🌿 ")
                 + HealthPresentation.trendTitle(entry.snapshot, at: entry.date))
        } else {
            Text((entry.snapshot?.isDemo == true ? GroveCopy.text("演示 · ", "DEMO · ") : "")
                 + "\(entry.metric == .steps ? GroveCopy.text("步", "steps") : "HRV") · \(HealthPresentation.value(reading))")
        }
    }
}

private struct GroveWidget: Widget {
    let metric: WidgetMetric
    let kind: String

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GroveWidgetProvider(metric: metric)) { entry in
            GroveWidgetView(entry: entry)
        }
        .configurationDisplayName(metric.title)
        .description(GroveCopy.text("显示腕森设备内的健康摘要。", "Show an on-device WristGrove summary."))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct WristGroveWidgets: WidgetBundle {
    var body: some Widget {
        GroveWidget(metric: .trend, kind: "wristgrove.trend")
        GroveWidget(metric: .hrv, kind: "wristgrove.hrv")
        GroveWidget(metric: .steps, kind: "wristgrove.steps")
    }
}
