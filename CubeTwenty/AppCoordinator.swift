import AppKit
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
    }

    deinit {
        wsObservers.forEach  { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        dncObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }

    // MARK: - 番茄钟联动

    private func setupCoordination() {
        pomodoroModel.$phase
            .dropFirst()                    // 忽略初始 .idle，避免启动时误触
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                self?.handlePhaseChange(phase)
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

    /// 屏幕完全可用（亮屏 + 未锁定）且番茄钟不在休息 → 重置并恢复眼部提醒计时
    private func resumeIfFullyActive() {
        guard !displayIsSleeping, !screenIsLocked, !eyePausedByPomodoro else { return }
        eyeReminderModel.resume()   // 内部调用 startTimer()，重置为完整间隔
    }
}
