import AppKit
import SwiftUI

@main
struct SleeplessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = SleepManager()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(manager)
        } label: {
            Image(systemName: manager.isActive ? "cup.and.saucer.fill" : "moon.zzz")
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
