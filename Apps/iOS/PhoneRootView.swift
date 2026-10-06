import SwiftUI
import Charts
import WristGroveCore

struct PhoneRootView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { TodayView() }
                .tabItem { Label(GroveCopy.text("今日", "Today"), systemImage: "leaf") }
                .tag(0)
            NavigationStack { TrendsView() }
                .tabItem { Label(GroveCopy.text("趋势", "Trends"), systemImage: "chart.xyaxis.line") }
                .tag(1)
            NavigationStack { SettingsView() }
                .tabItem { Label(GroveCopy.text("设置", "Settings"), systemImage: "slider.horizontal.3") }
                .tag(2)
        }
        .onOpenURL { url in
            if url.scheme == "wristgrove" { selection = 0 }
        }
    }
}

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    private let metrics: [MetricKind] = [.hrvSDNN, .heartRate, .restingHeartRate, .steps, .sleep]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    GroveMark(size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(GroveCopy.text("腕森", "WristGrove"))
                            .font(.largeTitle.weight(.semibold))
                        Text(GroveCopy.text("听见身体的节律", "A little space for your rhythm"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if model.isDemo {
                    demoCard
                }
                GroveCard { GroveTrendCard(snapshot: model.snapshot) }
                ForEach(metrics, id: \.rawValue) { metric in
                    NavigationLink {
                        PhoneMetricDetail(metric: metric)
                    } label: {
                        GroveCard {
                            HStack {
                                MetricTile(metric: metric, reading: model.snapshot?.reading(for: metric), isDemo: model.isDemo)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .accessibilityElement(children: .combine)
                }
                Text(GroveCopy.samplingExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                if let date = model.snapshot?.generatedAt {
                    Text(GroveCopy.text("数据更新", "Snapshot updated") + " · " + GroveCopy.timestamp(date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(GroveStyle.background(scheme))
        .foregroundStyle(GroveStyle.ink(scheme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isRefreshing { ProgressView() }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(model.isRefreshing)
                .accessibilityLabel(GroveCopy.text("刷新健康数据", "Refresh health data"))
            }
        }
        .refreshable { await model.refresh() }
    }

    private var demoCard: some View {
        GroveCard {
            VStack(alignment: .leading, spacing: 12) {
                DemoBadge()
                Text(GroveCopy.text("先逛一逛腕森。连接 Apple 健康后，就能查看自己的记录。",
                                    "Explore WristGrove first. Connect Apple Health to view your own records."))
                    .font(.subheadline)
                Button(GroveCopy.text("连接 Apple 健康", "Connect Apple Health")) {
                    Task { await model.connectHealth() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRefreshing)
            }
        }
    }
}

struct PhoneMetricDetail: View {
    @Environment(AppModel.self) private var model
    let metric: MetricKind

    var body: some View {
        List {
            if model.isDemo { DemoBadge() }
            Section {
                MetricTile(metric: metric, reading: model.snapshot?.reading(for: metric), isDemo: model.isDemo)
                    .padding(.vertical, 10)
            }
            if metric == .hrvSDNN {
                Section(GroveCopy.text("相对个人历史", "Compared with your history")) {
                    GroveTrendCard(snapshot: model.snapshot)
                    Text(GroveCopy.text("HRV 使用 SDNN，以毫秒表示。最新一次读数和今日采样趋势是不同的信息。",
                                        "HRV uses SDNN in milliseconds. The latest reading and today's sampled trend are different information."))
                        .font(.footnote)
                }
            }
            Section(GroveCopy.text("了解这项数据", "About this reading")) {
                Text(GroveCopy.samplingExplanation).font(.footnote)
                Text(GroveCopy.text("数据由 Apple 健康提供。空白可能表示尚无记录或未开放读取；腕森无法区分这两种情况。",
                                    "Data comes from Apple Health. An empty result can mean no records or no read access; WristGrove cannot distinguish them."))
                    .font(.footnote)
            }
        }
        .navigationTitle(GroveCopy.metricTitle(metric))
    }
}

struct TrendsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selectedDays = 7

    private var points: [DailyHRVPoint] {
        let history = model.snapshot?.dailyHRV ?? []
        return Array(history.suffix(selectedDays))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if model.isDemo { DemoBadge() }
                GroveCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(GroveCopy.text("HRV 历史", "HRV history"), systemImage: "chart.xyaxis.line")
                            .font(.headline)
                        Picker(GroveCopy.text("时间范围", "Range"), selection: $selectedDays) {
                            Text(GroveCopy.text("7 天", "7 days")).tag(7)
                            Text(GroveCopy.text("28 天", "28 days")).tag(28)
                        }
                        .pickerStyle(.segmented)

                        if points.isEmpty {
                            ContentUnavailableView(
                                GroveCopy.text("记录积累中", "Gathering readings"),
                                systemImage: "leaf",
                                description: Text(GroveCopy.text(
                                    "连接 Apple 健康后，腕森会展示完整自然日的采样中位数。",
                                    "Connect Apple Health to view daily medians for complete calendar days."
                                ))
                            )
                        } else {
                            Chart(points, id: \.day) { point in
                                LineMark(
                                    x: .value(GroveCopy.text("日期", "Date"), point.day),
                                    y: .value("SDNN", point.medianMilliseconds)
                                )
                                .foregroundStyle(scheme == .dark ? GroveStyle.sage : GroveStyle.forest)
                                PointMark(
                                    x: .value(GroveCopy.text("日期", "Date"), point.day),
                                    y: .value("SDNN", point.medianMilliseconds)
                                )
                                .foregroundStyle(GroveStyle.sage)
                                .accessibilityLabel(GroveCopy.timestamp(point.day))
                                .accessibilityValue("\(point.medianMilliseconds.formatted(.number.precision(.fractionLength(0...1)))) ms · \(point.sampleCount)")
                            }
                            .chartYAxisLabel("SDNN · ms")
                            .frame(height: 220)
                            Text(GroveCopy.text(
                                "每个点是一日的样本中位数；不表示连续测量。",
                                "Each point is a day's sample median, not continuous monitoring."
                            ))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                GroveCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(GroveCopy.text("趋势说明", "About this trend"))
                            .font(.headline)
                        Text(GroveCopy.trendExplanation)
                            .font(.subheadline)
                        Text(GroveCopy.text(
                            "今天的分级会与相同本地时间窗口的历史数据比较。至少积累 7 个有效历史日。",
                            "Today's band compares the same local-time window across history and needs at least seven valid days."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(18)
        }
        .background(GroveStyle.background(scheme))
        .foregroundStyle(GroveStyle.ink(scheme))
        .navigationTitle(GroveCopy.text("趋势", "Trends"))
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section(GroveCopy.text("数据模式", "Data mode")) {
                Toggle(isOn: Binding(
                    get: { model.isDemo },
                    set: { enabled in Task { await model.setDemoMode(enabled) } }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(GroveCopy.text("演示数据", "Demo data"))
                        Text(GroveCopy.text(
                            "使用本地合成记录体验界面，不会混入健康数据。",
                            "Explore with local synthetic readings; they never mix with health data."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                if model.isDemo {
                    Button {
                        Task { await model.connectHealth() }
                    } label: {
                        Label(GroveCopy.text("连接 Apple 健康", "Connect Apple Health"), systemImage: "heart.text.square")
                    }
                } else {
                    Label(GroveCopy.text("只申请读取所需数据", "Read-only access to selected data"), systemImage: "lock.shield")
                    Text(GroveCopy.text(
                        "iPhone 设置 → 隐私与安全性 → 健康 → WristGrove",
                        "iPhone Settings → Privacy & Security → Health → WristGrove"
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section(GroveCopy.text("你的数据", "Your data")) {
                Text(GroveCopy.text(
                    "健康原始记录留在 Apple 健康。腕森只在设备上生成摘要，并同步到配对的 Apple Watch。",
                    "Original samples stay in Apple Health. WristGrove computes summaries on-device and syncs them to your paired Watch."
                ))
                .font(.footnote)
                Link(GroveCopy.text("隐私政策", "Privacy policy"), destination: URL(string: "https://github.com/jeanbai0818-cloud/wristgrove/blob/main/docs/PRIVACY.md")!)
                Button(GroveCopy.text("删除腕森本地摘要", "Delete WristGrove summaries"), role: .destructive) {
                    confirmClear = true
                }
            }

            Section {
                Text(GroveCopy.samplingExplanation)
                Text(GroveCopy.trendExplanation)
            } header: {
                Text(GroveCopy.text("健康数据提示", "Health data notes"))
            }
        }
        .navigationTitle(GroveCopy.text("设置", "Settings"))
        .confirmationDialog(
            GroveCopy.text("删除本机摘要？", "Delete local summaries?"),
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button(GroveCopy.text("删除摘要", "Delete summaries"), role: .destructive) {
                model.clearLocalSnapshots()
            }
        } message: {
            Text(GroveCopy.text(
                "这会删除腕森在本机保存的摘要，不会删除 Apple 健康中的原始数据。",
                "This deletes WristGrove summaries on this device, not original data in Apple Health."
            ))
        }
    }
}
