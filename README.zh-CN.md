# WristGrove／腕森

免费、开源的 Apple Watch 表盘伙伴。先选择并预览表盘要显示的健康信息，再按引导添加到 Apple Watch 表盘。健康数据在设备上处理，无订阅、广告、账号、服务器或分析追踪。

**项目正在开发，尚未发布 TestFlight 或 App Store。** 自动构建与真机验收、发布签名分别记录，不把代码完成等同于可安装版本发布。

## 首版功能

- iPhone：表盘工作台，可选择并预览压力参考、最近 HRV 或步数；另有健康读数和 7／28 天趋势。
- Apple Watch：近期读数、个人 HRV 趋势、一分钟呼吸引导。
- Apple Watch 表盘复杂功能与智能叠放：个人 HRV 趋势（作为压力参考）、最近 HRV、步数；支持圆形、矩形和行内布局。
- 原创森林视觉，简体中文／英文，深色模式与无障碍支持。

压力参考将 Apple Watch SDNN HRV 与同一时段的个人历史比较，不是心理压力的直接测量，也不用于疾病诊断或恢复能力评分。watchOS 要求用户在手表上确认表盘复杂功能和位置。采样与后台刷新由系统决定；数据注明实际采样时间，刷新按钮不会触发新的 HRV 测量。

## 开发与安装

最低 iOS 17／watchOS 10，Swift 6。完整 Xcode 用于构建 Apple 平台应用；共享核心包可单独测试：

```sh
swift test --package-path Packages/WristGroveCore
```

使用 `WristGrove.xcodeproj` 中的共享 scheme 运行应用。首次可主动选择演示模式；演示和真实健康数据独立存储。签名与安装见[开发说明](docs/DEVELOPMENT.md)。

## 开发路线

可运行原型 → 真实健康数据与表盘 → TestFlight 内测 → 免费 App Store 应用。每一步以[路线图](docs/ROADMAP.md)和[验收清单](docs/ACCEPTANCE.md)为准。

开源许可：Apache 2.0。官方版本保持免费；许可允许第三方商业使用。
