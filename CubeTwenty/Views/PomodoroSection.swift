import SwiftUI
import SwiftData

struct PomodoroSection: View {

    @EnvironmentObject var model: PomodoroModel

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
            Button("开始专注（\(model.focusMinutes) 分钟）") {
                model.start()
            }
        } else {
            Text(statusText)
                .foregroundStyle(model.isRunning ? .primary : .secondary)

            Button(model.isRunning ? "暂停" : "继续") {
                model.isRunning ? model.pause() : model.start()
            }

            Button("重置") {
                model.reset()
            }
        }

        // 历史统计（有数据时显示）
        if !todaySessions.isEmpty || !weekSessions.isEmpty {
            let todayCount = todaySessions.count
            let weekCount  = weekSessions.count
            Text("今日 \(todayCount) 个 · 本周 \(weekCount) 个 🍅")
                .foregroundStyle(.secondary)
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
