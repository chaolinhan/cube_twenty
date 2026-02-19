import Foundation
import SwiftData

/// 一次完整专注周期的持久化记录
@Model
final class PomodoroSession {
    var completedAt: Date
    var durationMinutes: Int

    init(completedAt: Date = .now, durationMinutes: Int) {
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
    }
}
