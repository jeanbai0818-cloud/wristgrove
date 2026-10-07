import SwiftUI
import Charts
import WristGroveCore

struct PhoneRootView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { TodayView() }
                .tabItem { Label(GroveCopy.text("表盘", "Watch Face"), systemImage: "applewatch") }
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
    @AppStorage("wristgrove.faceSetupChoice") private var selectedChoiceKey = FaceDisplayChoice.stress.rawValue
    private let metrics: [MetricKind] = [.hrvSDNN, .heartRate, .restingHeartRate, .steps, .sleep]

    private var selectedChoice: FaceDisplayChoice {
        get { FaceDisplayChoice(rawValue: selectedChoiceKey) ?? .stress }
        nonmutating set { selectedChoiceKey = newValue.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    GroveMark(size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(GroveCopy.text("表盘工作台", "Watch Face Studio"))
                            .font(.largeTitle.weight(.semibold))
                        Text(GroveCopy.text("选择要抬腕查看的健康信息", "Choose what you want to see at a glance"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if model.isDemo { DemoBadge() }
                if model.isWatchAppInstalled == false {
                    WatchAppInstallNotice()
                }
                GroveCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(GroveCopy.text("表盘显示预览", "Watch face preview"), systemImage: "applewatch")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        FaceComplicationPreview(choice: selectedChoice, snapshot: model.snapshot)
                        Text(selectedChoice.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(GroveCopy.text("选择表盘显示内容", "Choose what to show on the face"))
                        .font(.headline)
                    ForEach(FaceDisplayChoice.allCases) { choice in
                        Button { selectedChoice = choice } label: {
                            FaceDisplayChoiceRow(choice: choice,
                                                 selected: selectedChoice == choice,
                                                 snapshot: model.snapshot)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedChoice == choice ? .isSelected : [])
                    }
                }
                NavigationLink {
                    WatchFaceSetupGuideView(choice: selectedChoice)
                } label: {
                    Label(GroveCopy.text("添加到表盘", "Add to watch face"), systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(GroveStyle.forest)
                Text(GroveCopy.text("腕森提供表盘显示项；watchOS 需要你在手表上确认表盘和显示位置。",
                                    "WristGrove provides face display options. Confirm the face and placement in watchOS."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if model.isDemo {
                    demoCard
                }
                DisclosureGroup(GroveCopy.text("其他健康数据", "Other health data")) {
                    VStack(spacing: 10) {
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
                    }
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

private struct WatchAppInstallNotice: View {
    var body: some View {
        GroveCard {
            Label {
                VStack(alignment: .leading, spacing: 6) {
                    Text(GroveCopy.text("先把腕森安装到手表", "Install WristGrove on Apple Watch"))
                        .font(.subheadline.weight(.semibold))
                    Text(GroveCopy.watchAppInstallNotice)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "applewatch.watchface")
                    .font(.title2)
                    .foregroundStyle(GroveStyle.forest)
            }
            .accessibilityElement(children: .combine)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(GroveStyle.sage.opacity(0.55), lineWidth: 1)
        }
    }
}

private enum FaceDisplayChoice: String, CaseIterable, Identifiable, Equatable {
    case stress, latestHRV, steps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stress: GroveCopy.text("压力参考", "Stress reference")
        case .latestHRV: GroveCopy.text("最近 HRV", "Latest HRV")
        case .steps: GroveCopy.text("今日步数", "Today's steps")
        }
    }

    var symbol: String {
        switch self {
        case .stress: "waveform.path.ecg"
        case .latestHRV: "heart"
        case .steps: "figure.walk"
        }
    }

    var metric: MetricKind { self == .steps ? .steps : .hrvSDNN }

    var description: String {
        switch self {
        case .stress:
            GroveCopy.text("比较同一时段的 SDNN HRV 与你的个人范围，作为压力参考。", "Compare SDNN HRV at the same time of day with your personal range as a stress reference.")
        case .latestHRV:
            GroveCopy.text("显示 Apple 健康记录的最近一次 SDNN HRV 和采样时间。", "Show the latest SDNN HRV reading from Apple Health and its sample time.")
        case .steps:
            GroveCopy.text("显示 Apple 健康记录的今日步数。", "Show today's step count from Apple Health.")
        }
    }

    var displayName: String { title }

    func value(in snapshot: HealthSnapshot?, at now: Date = Date()) -> String {
        if self == .stress {
            return HealthPresentation.compactTrendTitle(snapshot, at: now)
        }
        return HealthPresentation.value(snapshot?.reading(for: metric))
    }
}

private struct FaceComplicationPreview: View {
    let choice: FaceDisplayChoice
    let snapshot: HealthSnapshot?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [GroveStyle.night, GroveStyle.forest], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .stroke(.white.opacity(0.09), lineWidth: 1)
                .padding(18)
            VStack(spacing: 13) {
                Text(Date.now.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 34, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(GroveStyle.cream)
                HStack(spacing: 10) {
                    Image(systemName: choice.symbol)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(GroveStyle.sage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(choice.title.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(.white.opacity(0.72))
                        Text(choice.value(in: snapshot))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(GroveStyle.cream)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "leaf")
                        .font(.caption)
                        .foregroundStyle(GroveStyle.sage.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 17))
            }
            .padding(22)
        }
        .frame(height: 220)
        .overlay(alignment: .bottomTrailing) {
            Text(GroveCopy.text("腕森表盘预览", "WRISTGROVE FACE PREVIEW"))
                .font(.system(size: 8, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.55))
                .padding(14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GroveCopy.text("表盘显示预览：\(choice.title)，\(choice.value(in: snapshot))",
                                           "Watch face preview: \(choice.title), \(choice.value(in: snapshot))"))
    }
}

private struct FaceDisplayChoiceRow: View {
    @Environment(\.colorScheme) private var scheme
    let choice: FaceDisplayChoice
    let selected: Bool
    let snapshot: HealthSnapshot?

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: choice.symbol)
                .font(.title3)
                .foregroundStyle(selected ? GroveStyle.forest : .secondary)
                .frame(width: 40, height: 40)
                .background(GroveStyle.sage.opacity(selected ? 0.3 : 0.13), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(choice.title).font(.subheadline.weight(.semibold))
                Text(choice.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Text(choice.value(in: snapshot))
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? GroveStyle.forest : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(GroveStyle.forest)
            }
        }
        .padding(13)
        .background(GroveStyle.card(scheme), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(selected ? GroveStyle.sage : .clear, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WatchFaceSetupGuideView: View {
    @Environment(AppModel.self) private var model
    let choice: FaceDisplayChoice

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isWatchAppInstalled == false {
                    WatchAppInstallNotice()
                }
                GroveCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(GroveCopy.faceSetupTitle, systemImage: "applewatch")
                            .font(.headline)
                        Text(GroveCopy.faceSetupLimit)
                            .font(.subheadline)
                        Text(GroveCopy.trendExplanation)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(Array(GroveCopy.faceSetupSteps(displayName: choice.displayName).enumerated()), id: \.offset) { index, step in
                    GroveCard {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(GroveStyle.forest)
                                .frame(width: 28, height: 28)
                                .background(GroveStyle.sage.opacity(0.28), in: Circle())
                            Text(step)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(18)
        }
        .navigationTitle(GroveCopy.faceSetupTitle)
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
                Text(model.isDemo
                     ? GroveCopy.text("当前显示本地合成演示数据，不需要健康权限。连接 Apple 健康后，读数会注明真实采样时间。",
                                      "These are local synthetic demo readings and need no Health access. After connecting Apple Health, each reading shows its actual sample time.")
                     : GroveCopy.samplingExplanation)
                    .font(.footnote)
                Text(model.isDemo
                     ? GroveCopy.text("演示数值不来自 Apple 健康，也不会与真实数据混合。",
                                      "Demo values do not come from Apple Health and are never mixed with real data.")
                     : GroveCopy.text("数据由 Apple 健康提供。空白可能表示尚无记录或未开放读取；腕森无法区分这两种情况。",
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
