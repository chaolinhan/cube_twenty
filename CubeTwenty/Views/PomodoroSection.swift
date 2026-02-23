import SwiftUI
import SwiftData

struct PomodoroSection: View {

    @EnvironmentObject var model: PomodoroModel
    @Environment(\.modelContext) private var modelContext

    // 今日完成的专注记录
    @Query(filter: #Predicate<PomodoroSession> { session in
        session.completedAt >= startOfToday
    }) private var todaySessions: [PomodoroSession]

    // 本周完成的专注记录
    @Query(filter: #Predicate<PomodoroSession> { session in
        session.completedAt >= startOfWeek
    }) private var weekSessions: [PomodoroSession]

    var body: some View {
        if model.phase == .idle {
            Button { model.start() } label: {
                Label("开始专注（\(model.focusMinutes) 分钟）", systemImage: "timer")
            }
        } else {
            Text(statusText)
                .foregroundStyle(model.isRunning ? .primary : .secondary)

            Button {
                model.isRunning ? model.pause() : model.start()
            } label: {
                Label(model.isRunning ? "暂停" : "继续",
                      systemImage: model.isRunning ? "pause.fill" : "play.fill")
            }

            Button { model.reset() } label: {
                Label("重置", systemImage: "arrow.counterclockwise")
            }
        }

        // 查看统计按钮（有历史数据时显示）
        if !todaySessions.isEmpty || !weekSessions.isEmpty {
            Button {
                StatsPanelController.shared.show(container: modelContext.container)
            } label: {
                Label("查看统计...", systemImage: "chart.bar")
            }
        }
    }

    // MARK: - 辅助

    private var statusText: String {
        let m = model.minutesRemaining
        let timeLabel = m <= 1 ? "不到 1 分钟" : "约 \(m) 分钟"
        switch model.phase {
        case .idle:       return ""
        case .focusing:   return model.isRunning ? "专注中 · \(timeLabel)" : "专注已暂停 · \(timeLabel)"
        case .shortBreak: return "短休息 · \(timeLabel)"
        case .longBreak:  return "长休息 · \(timeLabel)"
        }
    }
}

// MARK: - 查询时间边界（文件级计算属性，@Query 的 filter 要求静态上下文）

private var startOfToday: Date {
    Calendar.current.startOfDay(for: .now)
}

private var startOfWeek: Date {
    let cal = Calendar.current
    return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? startOfToday
}
