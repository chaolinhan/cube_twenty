import AppKit
import ApplicationServices
import Combine
import SwiftData

/// 持有两个核心 Model，并通过 Combine 订阅协调它们之间的联动逻辑。
///
/// 联动规则：
/// - 番茄钟进入 shortBreak / longBreak → 暂停 20-20-20 计时器
/// - 番茄钟离开休息（回到 idle）      → 恢复 20-20-20 计时器（重置为完整间隔）
/// - 显示器熄屏 / 锁屏               → 暂停 20-20-20 计时器
/// - 显示器亮屏 + 解锁               → 恢复 20-20-20 计时器（重置为完整间隔）
final class AppCoordinator: ObservableObject {

    let eyeReminderModel = EyeReminderModel()
    let pomodoroModel    = PomodoroModel()
    let sparkleUpdater   = SparkleUpdater()
    let modelContainer: ModelContainer

    /// 标记"是由番茄钟主动暂停了眼部提醒"，防止在非休息状态误触 resume
    private var eyePausedByPomodoro = false

    /// 屏幕状态：两个独立标志，同时为 false 时才视为"屏幕可用"
    private var displayIsSleeping = false   // screensDidSleep / screensDidWake
    private var screenIsLocked    = false   // com.apple.screenIsLocked / Unlocked
    /// 前台应用是否处于全屏模式（需辅助功能权限；无权限时始终为 false）
    private var appIsFullscreen   = false

    private var cancellables    = Set<AnyCancellable>()
    /// addObserver(forName:...) 返回的 token，分源存储以便正确清理
    private var wsObservers:  [NSObjectProtocol] = []
    private var dncObservers: [NSObjectProtocol] = []

    init() {
        do {
            modelContainer = try ModelContainer(for: PomodoroSession.self)
        } catch {
            fatalError("SwiftData ModelContainer 初始化失败：\(error)")
        }
        pomodoroModel.configure(modelContext: ModelContext(modelContainer))
        setupCoordination()
        setupScreenMonitoring()
        setupFullscreenMonitoring()
    }

    deinit {
        wsObservers.forEach  { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        dncObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }

    // MARK: - 番茄钟联动

    private func setupCoordination() {
        pomodoroModel.$phase
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                self?.handlePhaseChange(phase)
            }
            .store(in: &cancellables)

        // 用户切换"全屏时暂停"开关时，立即重新评估当前状态
        eyeReminderModel.$pauseWhenFullscreen
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFullscreenState()
            }
            .store(in: &cancellables)
    }

    private func handlePhaseChange(_ phase: PomodoroPhase) {
        switch phase {
        case .shortBreak, .longBreak:
            // 进入休息：暂停 20-20-20（仅在已启用时才需要暂停并记录标记）
            if eyeReminderModel.isEnabled {
                eyeReminderModel.pause()
                eyePausedByPomodoro = true
            }

        case .idle, .focusing:
            // 离开休息（或重置）：若之前由番茄钟暂停，则恢复
            if eyePausedByPomodoro {
                eyePausedByPomodoro = false
                resumeIfFullyActive()   // 屏幕若仍熄屏/锁定，则不会真正恢复
            }
        }
    }

    // MARK: - 屏幕睡眠 / 锁屏监听

    private func setupScreenMonitoring() {
        let wsnc = NSWorkspace.shared.notificationCenter
        let dnc  = DistributedNotificationCenter.default()

        wsObservers = [
            wsnc.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                             object: nil, queue: .main) { [weak self] _ in
                self?.displayIsSleeping = true
                self?.pauseIfNeeded()
            },
            wsnc.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                             object: nil, queue: .main) { [weak self] _ in
                self?.displayIsSleeping = false
                self?.resumeIfFullyActive()
            },
        ]

        dncObservers = [
            dnc.addObserver(forName: .init("com.apple.screenIsLocked"),
                            object: nil, queue: .main) { [weak self] _ in
                self?.screenIsLocked = true
                self?.pauseIfNeeded()
            },
            dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"),
                            object: nil, queue: .main) { [weak self] _ in
                self?.screenIsLocked = false
                self?.resumeIfFullyActive()
            },
        ]
    }

    /// 屏幕变为不可用（熄屏或锁定）→ 暂停眼部提醒计时
    private func pauseIfNeeded() {
        guard eyeReminderModel.isEnabled else { return }
        eyeReminderModel.pause()
    }

    /// 屏幕完全可用（亮屏 + 未锁定）且番茄钟不在休息、非全屏 → 重置并恢复眼部提醒计时
    private func resumeIfFullyActive() {
        guard !displayIsSleeping, !screenIsLocked, !eyePausedByPomodoro, !appIsFullscreen else { return }
        eyeReminderModel.resume()
    }

    // MARK: - 全屏监听

    private func setupFullscreenMonitoring() {
        let wsnc = NSWorkspace.shared.notificationCenter
        let fullscreenObservers: [NSObjectProtocol] = [
            // 切换 Space（全屏进入/退出通常会创建新 Space）
            wsnc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                             object: nil, queue: .main) { [weak self] _ in
                self?.updateFullscreenState()
            },
            // 切换前台应用
            wsnc.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                             object: nil, queue: .main) { [weak self] _ in
                self?.updateFullscreenState()
            },
        ]
        wsObservers.append(contentsOf: fullscreenObservers)
    }

    private func updateFullscreenState() {
        guard eyeReminderModel.pauseWhenFullscreen else {
            if appIsFullscreen {
                appIsFullscreen = false
                eyeReminderModel.isPausedByFullscreen = false
                resumeIfFullyActive()
            }
            return
        }

        let wasFullscreen = appIsFullscreen
        appIsFullscreen = isFrontmostAppFullscreen()
        eyeReminderModel.isPausedByFullscreen = appIsFullscreen

        if appIsFullscreen && !wasFullscreen {
            pauseIfNeeded()
        } else if !appIsFullscreen && wasFullscreen {
            resumeIfFullyActive()
        }
    }

    /// 通过 Accessibility API 检查前台应用是否有全屏窗口。
    /// 未授权辅助功能权限时返回 false（优雅降级）。
    private func isFrontmostAppFullscreen() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return false }

        for window in windows {
            var ref: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &ref) == .success,
               let isFullscreen = ref as? Bool, isFullscreen {
                return true
            }
        }
        return false
    }
}
