# CubeTwenty — macOS 菜单栏工具

## 项目概述

macOS 原生菜单栏小工具，包含两个核心功能：
1. **20-20-20 眼部提醒**：每 20 分钟通过系统通知提醒用户看向 20 尺外至少 20 秒
2. **番茄钟**：可自定义专注/休息时长，支持长休息和会话历史记录

**分发方式**：直接分发（非 AppStore），无沙盒限制
**最低系统要求**：macOS 14 Sonoma（SwiftData、SettingsLink 等 API 需要）

---

## 技术架构

| 层次 | 选型 | 备注 |
|:--|:--|:--|
| 入口 | `@main App` + `MenuBarExtra` | macOS 13+ 纯 SwiftUI |
| UI 样式 | `.menu` 原生下拉菜单 | 轻量，与系统风格一致 |
| 架构 | MV 模式 + `@Observable` | 无 ViewModel 层，直接绑定 |
| 计时器 | `DispatchSourceTimer` | 后台精度更高，避免 Timer 漂移 |
| 通知 | `UserNotifications` framework | 系统原生通知，非侵入式 |
| 持久化 | `SwiftData` | 会话历史记录 |
| 自启动 | `SMAppService` | macOS 13+ 推荐方案 |
| 更新 | `Sparkle 2.x` | 非 AppStore 分发 |
| 隐藏 Dock | `LSUIElement = YES` | Info.plist 配置 |

### 依赖项

- **Sparkle** (2.x) — 自动更新：https://github.com/sparkle-project/Sparkle
- 无其他第三方依赖（计时器/通知均使用系统框架）

---

## 项目结构

```
CubeTwenty/
├── CubeTwentyApp.swift           # @main 入口，MenuBarExtra 定义
├── Info.plist                    # LSUIElement = YES，隐藏 Dock 图标
├── Models/
│   ├── EyeReminderModel.swift    # 20-20-20 状态机 + DispatchSourceTimer
│   ├── PomodoroModel.swift       # 番茄钟状态机 + 计时逻辑
│   └── PomodoroSession.swift     # SwiftData 模型，会话历史记录
├── Views/
│   ├── MenuBarContentView.swift  # 菜单根视图，组合两个 Section
│   ├── EyeReminderSection.swift  # 20-20-20 菜单区块
│   ├── PomodoroSection.swift     # 番茄钟菜单区块
│   └── SettingsView.swift        # 设置窗口（单独 Window Scene）
├── Services/
│   └── NotificationService.swift # 通知权限申请 + 发送封装
└── Resources/
    └── Assets.xcassets           # 菜单栏图标（模板图像，支持深/浅色）
```

---

## 核心功能规格

### 20-20-20 眼部提醒

- **默认间隔**：20 分钟（可在设置中自定义，范围 5–60 分钟）
- **提醒方式**：系统通知（`UNUserNotificationCenter`），标题"眼部休息提醒"，副标题"现在看向 20 尺（6米）以外的地方，持续 20 秒"
- **菜单显示**：启用/禁用开关 + 下次提醒时间（如"下次：14:32"）
- **与番茄钟联动**：番茄钟处于休息阶段时，20-20-20 计时器暂停，休息结束后自动恢复，并重置 20 分钟计时

### 番茄钟

- **默认时长**：专注 25 分钟，短休息 5 分钟，长休息 15 分钟
- **长休息规则**：每完成 4 个番茄周期后触发长休息（N 可在设置中配置）
- **状态机**：`idle → focusing → shortBreak → longBreak → idle`
- **菜单栏图标**：静态图标（不在图标上显示倒计时，避免菜单栏拥挤）
- **菜单显示**：当前阶段 + 剩余时间 + [开始/暂停] [重置] 按钮
- **通知**：阶段切换时发送系统通知（"专注时间结束！开始休息"/"休息结束，继续专注！"）
- **会话历史**：每完成一个完整专注周期，用 SwiftData 写入一条记录（时间戳 + 时长），提供当日/本周完成数统计

### 设置项（独立 Settings 窗口）

- 20-20-20 提醒间隔
- 番茄钟：专注时长、短休息时长、长休息时长、触发长休息的番茄数
- 开机自启（`SMAppService` 切换）
- 通知权限状态提示与跳转

---

## 计时器实现说明

使用 `DispatchSourceTimer` 而非 `Timer`，原因：
- `Timer` 在 RunLoop 繁忙时会漂移
- `DispatchSourceTimer` 在后台队列运行，精度更高

```swift
// 示例模式
private var timer: DispatchSourceTimer?

func startTimer(interval: TimeInterval, handler: @escaping () -> Void) {
    timer = DispatchSource.makeTimerSource(queue: .main)
    timer?.schedule(deadline: .now() + interval, repeating: interval)
    timer?.setEventHandler(handler: handler)
    timer?.resume()
}
```

UI 更新每秒刷新一次剩余时间显示（用独立的 1 秒 UI 刷新 Timer）。

---

## 开发阶段

### Phase 1：项目骨架 ✅
- [x] 创建 Xcode 项目（App target，非沙盒，macOS 13+）— 由 xcodegen 从 `project.yml` 生成
- [x] 配置 Info.plist：`LSUIElement = YES`
- [x] 实现 `@main App` + `MenuBarExtra(.menu)` 骨架
- [x] 添加 Sparkle SPM 依赖（2.6.0+），appcast URL 待 Phase 7 配置

### Phase 2：20-20-20 核心
- [ ] 实现 `EyeReminderModel`（`@Observable`，DispatchSourceTimer）
- [ ] 实现 `NotificationService`（权限申请 + 发送）
- [ ] 实现 `EyeReminderSection` 菜单视图（开关 + 下次提醒时间）
- [ ] 应用启动时请求通知权限

### Phase 3：番茄钟核心
- [ ] 实现 `PomodoroModel`（状态机，DispatchSourceTimer）
- [ ] 实现 `PomodoroSection` 菜单视图（状态 + 倒计时 + 控制按钮）
- [ ] 阶段切换通知

### Phase 4：联动逻辑
- [ ] 番茄钟进入休息阶段时，调用 `EyeReminderModel.pause()`
- [ ] 番茄钟休息结束时，调用 `EyeReminderModel.resume()` 并重置计时

### Phase 5：会话历史
- [ ] 定义 `PomodoroSession` SwiftData 模型
- [ ] 番茄钟完成专注周期时写入记录
- [ ] 在菜单或设置中展示今日/本周完成数

### Phase 6：设置界面
- [ ] 创建独立 `Window` Scene 的设置视图
- [ ] 所有配置项存储至 `UserDefaults`（`@AppStorage`）
- [ ] `SMAppService` 开机自启开关

### Phase 7：收尾与分发
- [x] Sparkle 更新集成：`SparkleUpdater` 服务 + "检查更新..." 菜单项
- [x] Hardened Runtime entitlements 配置（`CubeTwenty.entitlements`）
- [x] Info.plist 补全 `SUFeedURL` / `SUPublicEDKey` 占位
- [ ] 菜单栏/App 图标：当前使用 SF Symbol `eye.circle`，正式图标需提供 PNG 素材
- [ ] Sparkle 密钥生成：`./bin/generate_keys`（Sparkle 包内），将公钥填入 Info.plist
- [ ] appcast.xml 托管：参考 Sparkle 文档生成并发布到真实服务器
- [ ] Developer ID 代码签名：在 project.yml 中填入 `DEVELOPMENT_TEAM`，用 Xcode 存档并导出

---

## 关键注意事项

1. **通知权限**：首次启动时请求，用户拒绝后在设置界面提示引导至系统偏好。
2. **App Nap**：直接分发无沙盒，但仍需在 `Info.plist` 中设置 `NSAppSleepDisabled` 或使用 `ProcessInfo.processInfo.beginActivity` 防止系统对后台计时器节流。
3. **菜单视图刷新**：`.menu` 样式的 `MenuBarExtra` 每次打开菜单时重新渲染，倒计时显示依赖 `@Observable` 自动更新，需确认菜单打开状态下的刷新行为。
4. **SwiftData 并发**：会话写入在主 actor 上执行，无需额外并发处理。
