import SwiftUI
import WristGroveCore

struct WatchRootView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [MetricKind] = []
    private let metrics: [MetricKind] = [.hrvSDNN, .heartRate, .restingHeartRate, .sleep, .steps]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    if model.isDemo { DemoBadge() }
                    GroveCard {
                        VStack(alignment: .leading, spacing: 8) {
                            GroveTrendCard(snapshot: model.snapshot, compact: true)
                            NavigationLink {
                                WatchFaceSetupGuideView()
                            } label: {
                                Label(GroveCopy.text("如何添加到表盘", "How to add to a watch face"), systemImage: "plus.circle")
                                    .font(.caption)
                            }
                        }
                    }
                    if model.isDemo {
                        GroveCard {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(GroveCopy.text(
                                    "连接此 Apple Watch 的健康数据，查看自己的读数。",
                                    "Connect this Apple Watch to view your own readings."
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                Button {
                                    Task { await model.connectHealth() }
                                } label: {
                                    Label(GroveCopy.text("连接 Apple 健康", "Connect Apple Health"),
                                          systemImage: "heart.text.square")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(GroveStyle.forest)
                                .disabled(model.isRefreshing)
                            }
                        }
                    }
                    ForEach(metrics, id: \.rawValue) { metric in
                        NavigationLink(value: metric) {
                            GroveCard {
                                MetricTile(metric: metric, reading: model.snapshot?.reading(for: metric),
                                           isDemo: model.isDemo, showsTime: false,
                                           showsRelativeAge: metric == .hrvSDNN)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink {
                        BreathingGuideView()
                    } label: {
                        Label(GroveCopy.text("一分钟呼吸", "One-minute breathing"), systemImage: "wind")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GroveStyle.forest)
                    Text(GroveCopy.text(
                        "采样时间以每项读数为准。刷新不会触发新的测量。",
                        "Each reading shows its own sample time. Refresh does not trigger a new measurement."
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
            .navigationTitle(GroveCopy.text("腕森", "WristGrove"))
            .navigationDestination(for: MetricKind.self) { metric in
                WatchMetricDetail(metric: metric)
            }
            .onOpenURL { url in
                guard url.scheme == "wristgrove",
                      let metricCode = url.pathComponents.last,
                      let metric = GroveCopy.metric(from: metricCode) else { return }
                path = [metric]
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(GroveCopy.text("刷新摘要", "Refresh summary"))
                }
            }
        }
    }
}

private struct WatchFaceSetupGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(GroveCopy.faceSetupLimit)
                    .font(.caption)
                ForEach(Array(GroveCopy.faceSetupSteps.enumerated()), id: \.offset) { index, step in
                    GroveCard {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(GroveStyle.forest)
                            Text(step)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Text(GroveCopy.trendExplanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle(GroveCopy.faceSetupTitle)
    }
}

struct WatchMetricDetail: View {
    @Environment(AppModel.self) private var model
    let metric: MetricKind

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if model.isDemo { DemoBadge() }
                MetricTile(metric: metric, reading: model.snapshot?.reading(for: metric), isDemo: model.isDemo)
                if metric == .hrvSDNN {
                    GroveCard {
                        VStack(alignment: .leading, spacing: 8) {
                            GroveTrendCard(snapshot: model.snapshot, compact: true)
                            Text(GroveCopy.trendExplanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text(GroveCopy.samplingExplanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle(GroveCopy.metricTitle(metric))
    }
}

private struct BreathingGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expanded = false
    @State private var instruction: String = GroveCopy.text("准备好后开始", "Begin when ready")
    @State private var isRunning = false
    @State private var isComplete = false

    var body: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(GroveStyle.sage.opacity(0.48))
                .overlay(Circle().stroke(GroveStyle.forest, lineWidth: 2))
                .frame(width: expanded ? 114 : 62, height: expanded ? 114 : 62)
                .accessibilityHidden(true)

            Text(instruction)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.updatesFrequently)

            if isComplete {
                Text(GroveCopy.text("练习已结束，没有记录健康数据。", "Session complete. No health data was recorded."))
                    .font(.caption)
                    .multilineTextAlignment(.center)
            } else if !isRunning {
                Button(GroveCopy.text("开始一分钟", "Start one minute")) {
                    start()
                }
                .buttonStyle(.borderedProminent)
                .tint(GroveStyle.forest)
            } else {
                Button(GroveCopy.text("结束", "End session"), role: .cancel) {
                    isRunning = false
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .navigationTitle(GroveCopy.text("呼吸", "Breathe"))
        .task(id: isRunning) {
            guard isRunning else { return }
            await runSession()
        }
    }

    private func start() {
        guard !isRunning else { return }
        isRunning = true
    }

    private func runSession() async {
        for _ in 0..<5 {
            guard !Task.isCancelled else { return }
            instruction = GroveCopy.text("吸气 · 4 秒", "Inhale · 4 seconds")
            withAnimation(.easeInOut(duration: 4)) { expanded = true }
            guard await pause(seconds: 4), !Task.isCancelled else { return }

            instruction = GroveCopy.text("呼气 · 8 秒", "Exhale · 8 seconds")
            withAnimation(.easeInOut(duration: 8)) { expanded = false }
            guard await pause(seconds: 8), !Task.isCancelled else { return }
        }
        instruction = GroveCopy.text("完成 · 谢谢你留出这一分钟", "Complete · Thanks for taking a minute")
        isRunning = false
        isComplete = true
    }

    private func pause(seconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }
}
