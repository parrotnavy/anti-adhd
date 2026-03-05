import Foundation
#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class UpdateService {
#if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController
#endif

    init(automaticallyChecksForUpdates: Bool) {
#if canImport(Sparkle)
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.automaticallyDownloadsUpdates = true
#endif
        UserDefaults.standard.set(true, forKey: "SUAutomaticallyUpdate")
        setAutomaticallyChecksForUpdates(automaticallyChecksForUpdates)
    }

    func checkForUpdates() {
#if canImport(Sparkle)
        updaterController.checkForUpdates(nil)
#endif
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
#if canImport(Sparkle)
        updaterController.updater.automaticallyChecksForUpdates = enabled
#endif
        UserDefaults.standard.set(enabled, forKey: "SUEnableAutomaticChecks")
    }
}
