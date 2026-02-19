import Foundation
import Combine

/// 20-20-20 眼部提醒的核心状态与计时逻辑
///
/// 仅在主线程访问（DispatchSourceTimer 使用 .main 队列，SwiftUI 在主线程观察）
final class EyeReminderModel: ObservableObject {

    // MARK: - 发布状态

    @Published private(set) var isEnabled: Bool
    @Published private(set) var nextReminderDate: Date?

    // MARK: - 配置（@Published，SwiftUI 可观察；didSet 持久化并重启计时器）

    /// 提醒间隔（分钟），默认 20
    @Published var intervalMinutes: Int = 20 {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Keys.interval)
            if isEnabled { startTimer() }
        }
    }

    // MARK: - 私有

    private var dispatchTimer: DispatchSourceTimer?

    private enum Keys {
        static let enabled  = "eyeReminderEnabled"
        static let interval = "eyeReminderInterval"
    }

    // MARK: - 初始化

    init() {
        let savedEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        self.isEnabled = savedEnabled
        self.intervalMinutes = UserDefaults.standard.object(forKey: Keys.interval) as? Int ?? 20
        if savedEnabled {
            // 延迟一个 runloop，等 App 完全启动后再启动计时器
            DispatchQueue.main.async { [weak self] in
                self?.startTimer()
            }
        }
    }

    deinit {
        stopTimer()
    }

    // MARK: - 公开控制

    func toggle() {
        if isEnabled { disable() } else { enable() }
    }

    func enable() {
        isEnabled = true
        UserDefaults.standard.set(true, forKey: Keys.enabled)
        startTimer()
    }

    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Keys.enabled)
        stopTimer()
        nextReminderDate = nil
    }

    /// 手动立即触发一次提醒（同时重置计时器）
    func triggerNow() {
        fireReminder()
        if isEnabled { startTimer() }
    }

    // MARK: - Pomodoro 联动（Phase 4 调用）

    /// 番茄钟进入休息时调用：暂停计时，但不改变 isEnabled
    func pause() {
        stopTimer()
        nextReminderDate = nil
    }

    /// 番茄钟休息结束时调用：重新从头计时
    func resume() {
        guard isEnabled else { return }
        startTimer()
    }

    // MARK: - 私有计时器

    private func startTimer() {
        stopTimer()

        let interval = TimeInterval(intervalMinutes * 60)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.fireReminder()
        }
        timer.resume()
        dispatchTimer = timer
        nextReminderDate = Date().addingTimeInterval(interval)
    }

    private func stopTimer() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
    }

    private func fireReminder() {
        NotificationService.shared.sendEyeReminder()
        // 更新下次提醒时间（repeating 模式下 timer 会自动再次触发）
        nextReminderDate = Date().addingTimeInterval(TimeInterval(intervalMinutes * 60))
    }
}
