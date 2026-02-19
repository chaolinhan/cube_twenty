import Foundation
import SwiftData

// MARK: - 阶段枚举

enum PomodoroPhase: Equatable {
    case idle
    case focusing
    case shortBreak
    case longBreak
}

// MARK: - 模型

/// 番茄钟状态机
///
/// 状态流转：idle → focusing → shortBreak/longBreak → idle
///
/// ## 刷新频率设计
/// `timeRemaining` 是非 @Published 的内部变量，每秒递减但不触发视图重建。
/// 菜单视图只观察 `minutesRemaining`（每分钟至多变化一次），避免原生菜单
/// 每秒重建导致 hover 高亮跳位的问题。
final class PomodoroModel: ObservableObject {

    // MARK: - 发布状态（菜单视图所需的最小集合）

    @Published private(set) var phase: PomodoroPhase = .idle
    @Published private(set) var isRunning: Bool = false
    /// 剩余整分钟数，至多每分钟更新一次 —— 驱动菜单视图刷新
    @Published private(set) var minutesRemaining: Int = 0
    /// 本次 App 会话内完成的专注周期数（Phase 5 将持久化）
    @Published private(set) var completedPomodoros: Int = 0

    // MARK: - 内部计时（不触发视图重建）

    /// 精确剩余秒数，仅供内部逻辑使用，非 @Published
    private var timeRemaining: Int = 0

    // MARK: - 配置（@Published，SwiftUI 可观察；didSet 持久化）

    @Published var focusMinutes: Int = 25 {
        didSet { UserDefaults.standard.set(focusMinutes, forKey: Keys.focus) }
    }
    @Published var shortBreakMinutes: Int = 5 {
        didSet { UserDefaults.standard.set(shortBreakMinutes, forKey: Keys.shortBreak) }
    }
    @Published var longBreakMinutes: Int = 15 {
        didSet { UserDefaults.standard.set(longBreakMinutes, forKey: Keys.longBreak) }
    }
    @Published var pomodorosBeforeLongBreak: Int = 4 {
        didSet { UserDefaults.standard.set(pomodorosBeforeLongBreak, forKey: Keys.longBreakAfter) }
    }

    // MARK: - 私有

    private var modelContext: ModelContext?
    private var tickTimer: DispatchSourceTimer?

    private enum Keys {
        static let focus          = "pomodoroFocus"
        static let shortBreak     = "pomodoroShortBreak"
        static let longBreak      = "pomodoroLongBreak"
        static let longBreakAfter = "pomodoroLongBreakAfter"
    }

    init() {
        // Swift 在 init() 内赋值不触发 didSet，所以需要手动读取已存储的配置
        self.focusMinutes            = UserDefaults.standard.object(forKey: Keys.focus)          as? Int ?? 25
        self.shortBreakMinutes       = UserDefaults.standard.object(forKey: Keys.shortBreak)     as? Int ?? 5
        self.longBreakMinutes        = UserDefaults.standard.object(forKey: Keys.longBreak)      as? Int ?? 15
        self.pomodorosBeforeLongBreak = UserDefaults.standard.object(forKey: Keys.longBreakAfter) as? Int ?? 4
    }

    deinit { stopTicker() }

    /// 由 AppCoordinator 在 ModelContainer 创建后注入
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - 公开控制

    func start() {
        if phase == .idle {
            phase = .focusing
            setTimeRemaining(focusMinutes * 60)
        }
        isRunning = true
        startTicker()
    }

    func pause() {
        isRunning = false
        stopTicker()
    }

    func reset() {
        stopTicker()
        phase = .idle
        isRunning = false
        timeRemaining = 0
        minutesRemaining = 0
        completedPomodoros = 0
    }

    // MARK: - 私有计时器

    private func startTicker() {
        stopTicker()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        tickTimer = timer
    }

    private func stopTicker() {
        tickTimer?.cancel()
        tickTimer = nil
    }

    private func tick() {
        guard timeRemaining > 0 else {
            phaseComplete()
            return
        }
        timeRemaining -= 1
        // 只在分钟数发生变化时才发布，避免每秒触发菜单重建
        let newMinutes = ceilMinutes(timeRemaining)
        if newMinutes != minutesRemaining {
            minutesRemaining = newMinutes
        }
        if timeRemaining == 0 {
            phaseComplete()
        }
    }

    // MARK: - 阶段切换

    private func phaseComplete() {
        stopTicker()

        switch phase {
        case .focusing:
            completedPomodoros += 1
            NotificationService.shared.sendPomodoroFocusComplete()
            saveSession()

            let isLongBreak = (completedPomodoros % pomodorosBeforeLongBreak == 0)
            if isLongBreak {
                phase = .longBreak
                setTimeRemaining(longBreakMinutes * 60)
            } else {
                phase = .shortBreak
                setTimeRemaining(shortBreakMinutes * 60)
            }
            isRunning = true
            startTicker()

        case .shortBreak, .longBreak:
            NotificationService.shared.sendPomodoroBreakComplete()
            phase = .focusing
            setTimeRemaining(focusMinutes * 60)
            isRunning = true
            startTicker()

        case .idle:
            break
        }
    }

    // MARK: - 辅助

    private func saveSession() {
        guard let context = modelContext else { return }
        let session = PomodoroSession(completedAt: .now, durationMinutes: focusMinutes)
        context.insert(session)
        try? context.save()
    }

    /// 同步设置内部秒数和对外发布的分钟数
    private func setTimeRemaining(_ seconds: Int) {
        timeRemaining = seconds
        minutesRemaining = ceilMinutes(seconds)
    }

    /// 向上取整的剩余分钟数（最小为 1，0 秒时由 phaseComplete 处理）
    private func ceilMinutes(_ seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return max(1, Int(ceil(Double(seconds) / 60.0)))
    }
}
