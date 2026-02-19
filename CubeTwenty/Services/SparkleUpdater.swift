import Foundation
import Combine
import Sparkle

/// Sparkle 更新控制器封装
///
/// 生命周期随 AppCoordinator，在 App 启动时自动开始后台检查更新。
/// 使用前需在 Info.plist 中配置：
///   - SUFeedURL：appcast.xml 的托管地址
///   - SUPublicEDKey：由 `sparkle-generate-keys` 生成的 Ed25519 公钥
final class SparkleUpdater: ObservableObject {

    @Published private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController
    private var cancellable: AnyCancellable?

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // KVO 观察 canCheckForUpdates（正在检查时为 false，避免重复触发）
        cancellable = controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
