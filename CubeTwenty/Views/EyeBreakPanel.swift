import AppKit
import SwiftUI

// MARK: - View Model

/// 倒计时状态，由 EyeBreakPanelController 持有并启动，SwiftUI 视图观察。
final class EyeBreakViewModel: ObservableObject {

    static let totalSeconds = 20

    @Published private(set) var secondsRemaining: Int = totalSeconds

    /// 倒计时自然结束时回调（由 Controller 注入）
    var onFinish:  (() -> Void)?
    /// 用户提前结束时回调（由 Controller 注入）
    var onDismiss: (() -> Void)?

    private var countdownTimer: DispatchSourceTimer?

    func start() {
        secondsRemaining = Self.totalSeconds
        scheduleTimer()
    }

    /// 幂等：已取消或 nil 时重复调用安全
    func cancelTimer() {
        countdownTimer?.cancel()
        countdownTimer = nil
    }

    private func scheduleTimer() {
        cancelTimer()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        countdownTimer = t
    }

    private func tick() {
        guard secondsRemaining > 0 else { return }
        secondsRemaining -= 1
        if secondsRemaining == 0 {
            cancelTimer()
            onFinish?()
        }
    }
}

// MARK: - Panel Controller

/// 管理浮动 NSPanel 的生命周期。使用 orderFrontRegardless() 避免
/// LSUIElement app 在无激活权限时 makeKeyAndOrderFront 静默失败。
final class EyeBreakPanelController: NSObject, NSWindowDelegate {

    static let shared = EyeBreakPanelController()
    private override init() {}

    private var panel: NSPanel?
    private let viewModel = EyeBreakViewModel()

    private let panelWidth:  CGFloat = 160
    private let panelHeight: CGFloat = 180
    private let margin:      CGFloat = 12

    // MARK: - 公开 API

    func show() {
        dismissWithoutNotification()        // re-entrant 安全：先关旧窗

        let newPanel = buildPanel()
        panel = newPanel

        viewModel.onFinish  = { [weak self] in self?.finishNaturally() }
        viewModel.onDismiss = { [weak self] in self?.dismissWithoutNotification() }
        viewModel.start()

        newPanel.orderFrontRegardless()
    }

    // MARK: - NSWindowDelegate

    /// X 按钮 / 程序调用 close() 都经此回调，统一取消计时器
    func windowWillClose(_ notification: Notification) {
        viewModel.cancelTimer()
        panel = nil
    }

    // MARK: - 私有

    private func finishNaturally() {
        NotificationService.shared.sendEyeBreakComplete()
        panel?.close()      // → windowWillClose → cancelTimer（幂等，安全）
        panel = nil
    }

    private func dismissWithoutNotification() {
        viewModel.cancelTimer()
        panel?.close()
        panel = nil
    }

    private func buildPanel() -> NSPanel {
        let p = NSPanel(
            contentRect: targetFrame(),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.isOpaque = false
        p.backgroundColor = .clear          // 让 SwiftUI .regularMaterial 透出
        p.hasShadow = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.delegate = self

        p.contentViewController = NSHostingController(
            rootView: EyeBreakPanelView(viewModel: viewModel)
        )
        return p
    }

    /// 定位到鼠标所在屏幕的右上角（菜单栏下方）
    private func targetFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        let vf = screen.visibleFrame          // 已排除菜单栏和 Dock
        let x = vf.maxX - panelWidth  - margin
        let y = vf.maxY - panelHeight - margin
        return NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }
}

// MARK: - SwiftUI View

struct EyeBreakPanelView: View {

    @ObservedObject var viewModel: EyeBreakViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("👁")
                .font(.system(size: 36))

            Text("看向远处")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("\(viewModel.secondsRemaining)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(countdownColor)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.3), value: viewModel.secondsRemaining)
                .monospacedDigit()              // 防止数字宽度变化引起布局抖动

            Button("提前结束") {
                viewModel.onDismiss?()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.callout)
        }
        .padding(20)
        .frame(width: 160, height: 180)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var countdownColor: Color {
        viewModel.secondsRemaining <= 5 ? .green : .primary
    }
}
