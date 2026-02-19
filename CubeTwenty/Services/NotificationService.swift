import Foundation
import UserNotifications

/// 通知权限申请与发送的统一入口
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - 权限

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("[NotificationService] 权限申请失败：\(error.localizedDescription)")
            }
        }
    }

    func checkPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - 番茄钟通知

    func sendPomodoroFocusComplete() {
        send(
            identifier: "pomodoro-focus-complete",
            title: "专注时间结束",
            body: "好好休息一下 ☕"
        )
    }

    func sendPomodoroBreakComplete() {
        send(
            identifier: "pomodoro-break-complete",
            title: "休息结束",
            body: "休息结束，自动开始专注 🍅"
        )
    }

    // MARK: - 20-20-20 提醒

    func sendEyeReminder() {
        // identifier 带时间戳，避免系统合并多条通知
        send(
            identifier: "eye-reminder-\(Date().timeIntervalSince1970)",
            title: "眼部休息提醒",
            body: "看向 20 尺（约 6 米）以外的地方，持续 20 秒"
        )
    }

    // MARK: - 私有

    private func send(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
