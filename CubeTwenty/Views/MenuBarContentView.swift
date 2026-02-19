import SwiftUI

/// 菜单栏下拉菜单的根视图
struct MenuBarContentView: View {

    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var updater: SparkleUpdater

    var body: some View {
        // ── 20-20-20 区块 ─────────────────────────────────────
        Section("眼部提醒") {
            EyeReminderSection()
        }

        Divider()

        // ── 番茄钟区块 ────────────────────────────────────────
        Section("番茄钟") {
            PomodoroSection()
        }

        Divider()

        // ── 底部操作 ──────────────────────────────────────────
        // openSettings 是 macOS 14 的正式 SwiftUI API，配合 NSApp.activate()
        // 解决 LSUIElement 应用窗口不浮到前台的问题
        Button {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("偏好设置...", systemImage: "gear")
        }

        Button("检查更新...") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)

        Button("退出 CubeTwenty") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
