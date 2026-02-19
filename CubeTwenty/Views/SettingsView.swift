import SwiftUI
import ServiceManagement
import UserNotifications

// MARK: - 根视图

struct SettingsView: View {
    @EnvironmentObject var eyeReminderModel: EyeReminderModel
    @EnvironmentObject var pomodoroModel: PomodoroModel

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("通用", systemImage: "gearshape") }

            EyeReminderSettingsTab()
                .tabItem { Label("眼部提醒", systemImage: "eye") }

            PomodoroSettingsTab()
                .tabItem { Label("番茄钟", systemImage: "timer") }
        }
        .frame(width: 420)
        // 环境对象自动透传给子视图
    }
}

// MARK: - 通用

private struct GeneralSettingsTab: View {

    @State private var autoLaunchEnabled = SMAppService.mainApp.status == .enabled
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                Toggle("开机自动启动", isOn: $autoLaunchEnabled)
                    .onChange(of: autoLaunchEnabled) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // 操作失败时回滚开关状态
                            autoLaunchEnabled = !enabled
                        }
                    }
            }

            Section("通知权限") {
                LabeledContent("当前状态") {
                    Text(notificationStatus.displayLabel)
                        .foregroundStyle(notificationStatus.displayColor)
                }

                if notificationStatus != .authorized {
                    Button("前往系统设置授权...") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = settings.authorizationStatus
        }
    }
}

// MARK: - 眼部提醒

private struct EyeReminderSettingsTab: View {

    @EnvironmentObject var model: EyeReminderModel

    var body: some View {
        Form {
            Section {
                Stepper("每 \(model.intervalMinutes) 分钟提醒一次",
                        value: $model.intervalMinutes,
                        in: 5...60, step: 5)
            } header: {
                Text("")
            } footer: {
                Text("20-20-20 法则建议保持 20 分钟间隔")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// MARK: - 番茄钟

private struct PomodoroSettingsTab: View {

    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        Form {
            Section("时长") {
                Stepper("专注 \(model.focusMinutes) 分钟",
                        value: $model.focusMinutes, in: 5...90, step: 5)
                Stepper("短休息 \(model.shortBreakMinutes) 分钟",
                        value: $model.shortBreakMinutes, in: 1...30, step: 1)
                Stepper("长休息 \(model.longBreakMinutes) 分钟",
                        value: $model.longBreakMinutes, in: 5...60, step: 5)
            }

            Section {
                Stepper("每 \(model.pomodorosBeforeLongBreak) 个番茄后触发",
                        value: $model.pomodorosBeforeLongBreak, in: 2...8, step: 1)
            } header: {
                Text("长休息")
            } footer: {
                Text("设置更改将在下一个番茄周期生效")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// MARK: - UNAuthorizationStatus 显示扩展

private extension UNAuthorizationStatus {
    var displayLabel: String {
        switch self {
        case .authorized:    return "已授权"
        case .denied:        return "已拒绝"
        case .notDetermined: return "未设置"
        case .provisional:   return "临时授权"
        case .ephemeral:     return "临时"
        @unknown default:    return "未知"
        }
    }

    var displayColor: Color {
        switch self {
        case .authorized: return .green
        case .denied:     return .red
        default:          return .orange
        }
    }
}
