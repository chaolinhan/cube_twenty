# CubeTwenty — macOS 菜单栏工具

## 项目概述

macOS 原生菜单栏小工具，包含两个核心功能：
1. **20-20-20 眼部提醒**：每 20 分钟通过系统通知提醒用户看向 20 尺外至少 20 秒
2. **番茄钟**：可自定义专注/休息时长，支持长休息和会话历史记录

**分发方式**：直接分发（非 AppStore），无沙盒限制
**最低系统要求**：macOS 14 Sonoma（SwiftData、`@Environment(\.openSettings)` 等 API 需要）

---

## 技术架构

| 层次 | 选型 | 备注 |
|:--|:--|:--|
| 入口 | `@main App` + `MenuBarExtra` | macOS 13+ 纯 SwiftUI |
| UI 样式 | `.menu` 原生下拉菜单 | 轻量，与系统风格一致 |
| 架构 | MV 模式 + `ObservableObject` | `@Published` 驱动视图更新 |
| 计时器 | `DispatchSourceTimer` | 后台精度更高，避免 Timer 漂移 |
| 通知 | `UserNotifications` framework | 系统原生通知，非侵入式 |
| 持久化 | `SwiftData` | 会话历史记录 |
| 自启动 | `SMAppService` | macOS 13+ 推荐方案 |
| 更新 | `Sparkle 2.x` | 非 AppStore 分发 |
| 隐藏 Dock | `LSUIElement = YES` | Info.plist 配置 |

> **注意**：使用 `ObservableObject` + `@Published` 而非 `@Observable` 宏。
> 原因：`.menu` 样式的 `MenuBarExtra` 在 `objectWillChange` 触发时重建原生菜单，
> 若每秒 publish `timeRemaining` 会导致鼠标悬停高亮跳位。
> 解决方案：`timeRemaining` 私有非发布，仅 `minutesRemaining`（每分钟变化）为 `@Published`。

### 依赖项

- **Sparkle** (2.x) — 自动更新：https://github.com/sparkle-project/Sparkle
- 无其他第三方依赖（计时器/通知均使用系统框架）

---

## 项目结构

```
CubeTwenty/
├── CubeTwentyApp.swift           # @main 入口，MenuBarExtra + Settings Scene
├── AppCoordinator.swift          # 协调层：持有两个 Model + SparkleUpdater + ModelContainer
├── Info.plist                    # LSUIElement = YES，隐藏 Dock 图标
├── CubeTwenty.entitlements       # Hardened Runtime，非沙盒
├── Models/
│   ├── EyeReminderModel.swift    # 20-20-20 状态机 + DispatchSourceTimer
│   ├── PomodoroModel.swift       # 番茄钟状态机 + 计时逻辑 + UserDefaults 配置
│   └── PomodoroSession.swift     # SwiftData 模型，会话历史记录
├── Views/
│   ├── MenuBarContentView.swift  # 菜单根视图，组合两个 Section
│   ├── EyeReminderSection.swift  # 20-20-20 菜单区块
│   ├── PomodoroSection.swift     # 番茄钟菜单区块（带 SF Symbol 图标）
│   └── SettingsView.swift        # 设置窗口（General / 眼部提醒 / 番茄钟 三 Tab）
├── Services/
│   ├── NotificationService.swift # 通知权限申请 + 发送封装（单例）
│   └── SparkleUpdater.swift      # SPUStandardUpdaterController 封装
└── Resources/
    └── Assets.xcassets/
        ├── AppIcon.appiconset/   # 🧿 emoji，极简浅蓝背景，CoreText 生成
        └── MenuBarIcon.imageset/ # 菜单栏模板图像
```

---

## 核心功能规格

### 20-20-20 眼部提醒

- **默认间隔**：20 分钟（可在设置中自定义，范围 5–60 分钟）
- **提醒方式**：系统通知（`UNUserNotificationCenter`），标题"眼部休息提醒"
- **菜单显示**：启用/禁用开关 + 下次提醒时间 + "立即提醒"按钮
- **与番茄钟联动**：番茄钟进入休息阶段时计时器暂停，休息结束后自动恢复并重置计时

### 番茄钟

- **默认时长**：专注 25 分钟，短休息 5 分钟，长休息 15 分钟
- **长休息规则**：每完成 4 个番茄周期后触发长休息（N 可在设置中配置）
- **状态机**：`idle → focusing → shortBreak → longBreak → idle`
- **菜单栏图标**：静态 SF Symbol `eye.circle`（不在图标上显示倒计时）
- **菜单显示**：当前阶段 + 剩余时间（分钟精度）+ 控制按钮（带 SF Symbol 图标）
- **通知**：阶段切换时发送系统通知
- **会话历史**：每完成一个完整专注周期写入 SwiftData 记录，菜单显示今日/本周完成数

### 设置项（独立 Settings 窗口，三 Tab）

| Tab | 内容 |
|-----|------|
| 通用 | 开机自启（`SMAppService`）、通知权限状态与跳转 |
| 眼部提醒 | 提醒间隔步进器（5–60 分钟，步长 5） |
| 番茄钟 | 专注/短休息/长休息时长、触发长休息的番茄数 |

所有配置通过 `@Published var + didSet` 写入 `UserDefaults`，`init()` 读取还原。

---

## 计时器实现说明

使用 `DispatchSourceTimer` 而非 `Timer`，原因：
- `Timer` 在 RunLoop 繁忙时会漂移
- `DispatchSourceTimer` 在后台队列运行，精度更高

```swift
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(1))
timer.setEventHandler { [weak self] in self?.tick() }
timer.resume()
```

---

## 开发阶段

### Phase 1：项目骨架 ✅
- [x] `project.yml` + xcodegen 生成 Xcode 项目
- [x] `LSUIElement = YES`，`MenuBarExtra(.menu)` 骨架
- [x] Sparkle SPM 依赖（2.6.0+）

### Phase 2：20-20-20 核心 ✅
- [x] `EyeReminderModel`（DispatchSourceTimer，`@Published` 状态）
- [x] `NotificationService` 单例（权限申请 + 发送）
- [x] `EyeReminderSection` 菜单视图

### Phase 3：番茄钟核心 ✅
- [x] `PomodoroModel` 状态机（`minutesRemaining` 防抖，避免菜单每秒重建）
- [x] `PomodoroSection` 菜单视图
- [x] 阶段切换系统通知

### Phase 4：联动逻辑 ✅
- [x] `AppCoordinator` 通过 Combine 订阅 `pomodoroModel.$phase`
- [x] 番茄钟休息时暂停眼部提醒，休息结束时恢复

### Phase 5：会话历史 ✅
- [x] `PomodoroSession` SwiftData 模型
- [x] `ModelContainer` 在 `AppCoordinator` 初始化
- [x] `PomodoroSection` 用 `@Query` 展示今日/本周完成数

### Phase 6：设置界面 ✅
- [x] 三 Tab `SettingsView`（General / 眼部提醒 / 番茄钟）
- [x] `SMAppService` 开机自启开关
- [x] `@Environment(\.openSettings)` + `NSApp.activate()` 解决 LSUIElement 焦点问题

### Phase 7：收尾与分发 ✅（代码完成，分发步骤待执行）
- [x] `SparkleUpdater` 封装 + "检查更新..." 菜单项
- [x] `CubeTwenty.entitlements`（Hardened Runtime，非沙盒）
- [x] `SUFeedURL` 占位（待替换为真实地址）
- [x] App 图标：🧿 emoji，极简浅蓝背景，CoreText + CoreGraphics Swift 脚本生成
- [x] 菜单按钮 SF Symbol 图标（`timer` / `pause.fill` / `play.fill` / `arrow.counterclockwise` / `eye.trianglebadge.exclamationmark`）
- [ ] Sparkle 密钥：运行 `./bin/generate_keys`（Sparkle 包内），将公钥填入 `Info.plist` 的 `SUPublicEDKey`
- [ ] appcast.xml：参考 Sparkle 文档生成并托管到真实服务器，更新 `SUFeedURL`
- [ ] Developer ID 签名：在 `project.yml` 填入 `DEVELOPMENT_TEAM`，Xcode Archive 导出

---

## 关键注意事项

1. **通知权限**：首次启动时请求，用户拒绝后在设置界面提示引导至系统偏好。
2. **App Nap**：直接分发无沙盒，仍需注意系统可能对后台计时器节流；可在 `Info.plist` 设置 `NSAppSleepDisabled` 或使用 `ProcessInfo.processInfo.beginActivity`。
3. **菜单视图刷新**：`.menu` 样式 `MenuBarExtra` 每次打开菜单时重建，`@Published` 变化触发 `objectWillChange`，需控制发布频率（见上方计时器说明）。
4. **SwiftData 并发**：会话写入在主 actor 执行，无需额外并发处理。
5. **xcodegen**：新增 Swift 文件后需重新运行 `xcodegen generate` 才能加入 Xcode project。
6. **图标生成脚本**：`/tmp/generate_icon.swift`（CoreText + CoreGraphics），运行命令：
   ```bash
   swift /tmp/generate_icon.swift "CubeTwenty/Resources/Assets.xcassets/AppIcon.appiconset"
   ```
