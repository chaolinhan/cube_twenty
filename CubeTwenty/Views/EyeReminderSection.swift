import SwiftUI

struct EyeReminderSection: View {

    @EnvironmentObject var model: EyeReminderModel

    var body: some View {
        // 启用/禁用开关（在 .menu 样式下渲染为带勾选的菜单项）
        Toggle(isOn: toggleBinding) {
            Label("20-20-20 提醒", systemImage: "eye")
        }

        if model.isEnabled {
            // 下次提醒时间
            if let next = model.nextReminderDate {
                Text("下次提醒：\(next.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            }

            // 手动立即触发
            Button { model.triggerNow() } label: {
                Label("立即提醒", systemImage: "eye.trianglebadge.exclamationmark")
            }
        }
    }

    /// 自定义 Binding：get/set 分离，确保 toggle 时通过模型方法处理计时器
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { model.isEnabled },
            set: { _ in model.toggle() }
        )
    }
}
