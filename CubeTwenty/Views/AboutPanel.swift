import AppKit
import SwiftUI

// MARK: - Controller

/// 关于窗口控制器（单例），管理 NSPanel 生命周期。
final class AboutPanelController: NSObject, NSWindowDelegate {

    static let shared = AboutPanelController()

    private var panel: NSPanel?
    private let panelWidth: CGFloat = 300
    private let panelHeight: CGFloat = 340

    /// 显示关于窗口。如果已打开，则将其带到前台。
    func show(updater: SparkleUpdater) {
        if let existing = panel {
            existing.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newPanel = buildPanel(updater: updater)
        panel = newPanel
        newPanel.center()
        newPanel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }

    private func buildPanel(updater: SparkleUpdater) -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        p.title = "关于 CubeTwenty"
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.delegate = self
        p.contentViewController = NSHostingController(
            rootView: AboutPanelView(updater: updater)
        )
        return p
    }
}

// MARK: - View

struct AboutPanelView: View {

    @ObservedObject var updater: SparkleUpdater

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 4)

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("CubeTwenty")
                .font(.title2.bold())

            Text("版本 \(appVersion) (\(buildNumber))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("macOS 菜单栏护眼提醒 + 番茄钟")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 4)

            Button("检查更新...") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)

            Spacer().frame(height: 4)

            Text("© 2025 LTN Studio")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Link("GitHub",
                 destination: URL(string: "https://github.com/chaolinhan/cube_twenty")!)
                .font(.caption)

            Spacer().frame(height: 4)
        }
        .padding(.horizontal, 24)
        .frame(width: 300, height: 340)
    }
}
