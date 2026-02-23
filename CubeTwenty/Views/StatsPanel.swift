import AppKit
import SwiftUI
import SwiftData

// MARK: - Controller

/// 番茄钟统计小窗控制器（单例），管理 NSPanel 生命周期。
final class StatsPanelController: NSObject, NSWindowDelegate {

    static let shared = StatsPanelController()

    private var panel: NSPanel?
    private let panelWidth:  CGFloat = 280
    private let panelHeight: CGFloat = 300

    func show(container: ModelContainer) {
        if let existing = panel {
            existing.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let newPanel = buildPanel(container: container)
        panel = newPanel
        newPanel.center()
        newPanel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }

    private func buildPanel(container: ModelContainer) -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        p.title = "番茄钟统计"
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.delegate = self
        p.contentViewController = NSHostingController(
            rootView: StatsPanelView()
                .modelContainer(container)
        )
        return p
    }
}

// MARK: - View

struct StatsPanelView: View {

    // 本周所有 session（用于热力图 + 本周数）
    @Query(filter: #Predicate<PomodoroSession> { s in
        s.completedAt >= statsStartOfWeek
    }) private var weekSessions: [PomodoroSession]

    // 今日所有 session
    @Query(filter: #Predicate<PomodoroSession> { s in
        s.completedAt >= statsStartOfToday
    }) private var todaySessions: [PomodoroSession]

    // 全部历史
    @Query private var allSessions: [PomodoroSession]

    var body: some View {
        VStack(spacing: 20) {
            Text("番茄钟统计")
                .font(.headline)

            // 本周热力图
            weekHeatmap

            // 数字统计行
            HStack(spacing: 0) {
                statCell(value: todaySessions.count, label: "今日")
                Divider().frame(height: 32)
                statCell(value: weekSessions.count, label: "本周")
                Divider().frame(height: 32)
                statCell(value: allSessions.count, label: "累计")
            }

            // 今日专注时长
            let todayMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
            if todayMinutes > 0 {
                Text("今日专注 \(todayMinutes) 分钟")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 280, height: 300)
    }

    // MARK: - 本周热力图

    private var weekHeatmap: some View {
        let cal = Calendar.current
        // 生成本周 7 天（周一到周日）
        let weekStart = statsStartOfWeek
        let days: [Date] = (0..<7).compactMap {
            cal.date(byAdding: .day, value: $0, to: weekStart)
        }
        // 按天分组计数
        let countsByDay: [Date: Int] = weekSessions.reduce(into: [:]) { dict, session in
            let day = cal.startOfDay(for: session.completedAt)
            dict[day, default: 0] += 1
        }

        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let count = countsByDay[cal.startOfDay(for: day)] ?? 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cellColor(count: count))
                        .frame(width: 26, height: 26)
                        .overlay(
                            count > 0 ?
                            Text("\(count)").font(.system(size: 10, weight: .medium)).foregroundStyle(.white)
                            : nil
                        )
                }
            }
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    Text(dayLabel(day))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 26)
                }
            }
        }
    }

    // MARK: - 辅助

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func cellColor(count: Int) -> Color {
        switch count {
        case 0:       return Color.gray.opacity(0.15)
        case 1:       return Color.orange.opacity(0.4)
        case 2, 3:    return Color.orange.opacity(0.7)
        default:      return Color.orange
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let labels = ["日", "一", "二", "三", "四", "五", "六"]
        return labels[weekday - 1]
    }
}

// MARK: - 查询时间边界（文件级，@Query filter 要求静态上下文）

private var statsStartOfToday: Date {
    Calendar.current.startOfDay(for: .now)
}

private var statsStartOfWeek: Date {
    let cal = Calendar.current
    return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? statsStartOfToday
}
