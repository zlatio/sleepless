import AppKit
import SwiftUI

/// Runs the CLI for a subcommand, otherwise the menu bar app.
@main
enum Entry {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        // Other dash arguments belong to the app, such as -psn_... from Launch Services and -NS... from Xcode.
        if let first = arguments.first, !first.hasPrefix("-") || ["-h", "--help", "--version"].contains(first) {
            CLI.run(arguments)
        }

        SleeplessApp.main()
    }
}

struct SleeplessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager: SleepManager

    init() {
        let manager = SleepManager()

        guard ControlPort.listen(for: manager) else {
            FileHandle.standardError.write(Data("Sleepless is already running.\n".utf8))
            exit(0)
        }

        _manager = StateObject(wrappedValue: manager)
    }

    var body: some Scene {
        MenuBarExtra("Sleepless", systemImage: manager.isActive ? "cup.and.saucer.fill" : "moon.zzz") {
            MenuView()
                .environmentObject(manager)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon (needed when run as a bare SPM binary).
        NSApp.setActivationPolicy(.accessory)
    }
}
