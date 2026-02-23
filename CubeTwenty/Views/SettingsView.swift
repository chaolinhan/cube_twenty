import SwiftUI
import ServiceManagement
import UserNotifications
import ApplicationServices

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
    @State private var accessibilityGranted = AXIsProcessTrusted()

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

            Section {
                LabeledContent("当前状态") {
                    Text(accessibilityGranted ? "已授权" : "未授权")
                        .foregroundStyle(accessibilityGranted ? .green : .orange)
                }

                if !accessibilityGranted {
                    Button("请求辅助功能权限...") {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            accessibilityGranted = AXIsProcessTrusted()
                        }
                    }
                }
            } header: {
                Text("辅助功能权限")
            } footer: {
                Text("全屏时暂停提醒功能需要辅助功能权限")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
        }
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
                HStack {
                    Text("提醒间隔")
                    Spacer()
                    Text("\(model.intervalMinutes) 分钟")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $model.intervalMinutes,
                            in: 5...60, step: 5)
                        .labelsHidden()
                }
            } footer: {
                Text("20-20-20 法则建议保持 20 分钟间隔")
            }

            Section {
                Toggle("全屏时暂停提醒", isOn: $model.pauseWhenFullscreen)
            } footer: {
                Text("当前台应用处于全屏模式时，自动暂停眼部提醒计时（需辅助功能权限）")
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
                HStack {
                    Text("专注时长")
                    Spacer()
                    Text("\(model.focusMinutes) 分钟")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $model.focusMinutes, in: 5...90, step: 5)
                        .labelsHidden()
                }
                HStack {
                    Text("短休息")
                    Spacer()
                    Text("\(model.shortBreakMinutes) 分钟")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $model.shortBreakMinutes, in: 1...30, step: 1)
                        .labelsHidden()
                }
                HStack {
                    Text("长休息")
                    Spacer()
                    Text("\(model.longBreakMinutes) 分钟")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $model.longBreakMinutes, in: 5...60, step: 5)
                        .labelsHidden()
                }
            }

            Section {
                HStack {
                    Text("长休息间隔")
                    Spacer()
                    Text("\(model.pomodorosBeforeLongBreak) 个番茄")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $model.pomodorosBeforeLongBreak, in: 2...8, step: 1)
                        .labelsHidden()
                }
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
