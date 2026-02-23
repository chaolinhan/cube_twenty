import SwiftUI

@main
struct CubeTwentyApp: App {

    @StateObject private var coordinator = AppCoordinator()

    init() {
        NotificationService.shared.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra("CubeTwenty", systemImage: "sunglasses.fill") {
            MenuBarContentView()
                .environmentObject(coordinator.eyeReminderModel)
                .environmentObject(coordinator.pomodoroModel)
                .environmentObject(coordinator.sparkleUpdater)
                .modelContainer(coordinator.modelContainer)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(coordinator.eyeReminderModel)
                .environmentObject(coordinator.pomodoroModel)
                .modelContainer(coordinator.modelContainer)
        }
    }
}
