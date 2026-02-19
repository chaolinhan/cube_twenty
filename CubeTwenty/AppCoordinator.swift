import Foundation
import Combine
import SwiftData

/// 持有两个核心 Model，并通过 Combine 订阅协调它们之间的联动逻辑。
///
/// 联动规则：
/// - 番茄钟进入 shortBreak / longBreak → 暂停 20-20-20 计时器
/// - 番茄钟离开休息（回到 idle）      → 恢复 20-20-20 计时器（重置为完整间隔）
/// - 番茄钟 reset / 纯 focus 操作    → 不影响 20-20-20
final class AppCoordinator: ObservableObject {

    let eyeReminderModel = EyeReminderModel()
    let pomodoroModel    = PomodoroModel()
    let sparkleUpdater   = SparkleUpdater()
    let modelContainer: ModelContainer

    /// 标记"是由番茄钟主动暂停了眼部提醒"，防止在非休息状态误触 resume
    private var eyePausedByPomodoro = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        do {
            modelContainer = try ModelContainer(for: PomodoroSession.self)
        } catch {
            fatalError("SwiftData ModelContainer 初始化失败：\(error)")
        }
        pomodoroModel.configure(modelContext: ModelContext(modelContainer))
        setupCoordination()
    }

    // MARK: - 私有

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
                eyeReminderModel.resume()
                eyePausedByPomodoro = false
            }
        }
    }
}
