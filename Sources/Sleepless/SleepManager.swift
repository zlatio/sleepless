import AppKit
import IOKit.pwr_mgt

enum KeepAwakeDuration: String, CaseIterable, Identifiable {
    case forever
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours

    var id: String { rawValue }

    var label: String {
        switch self {
        case .forever: "∞"
        case .fifteenMinutes: "15m"
        case .thirtyMinutes: "30m"
        case .oneHour: "1h"
        case .twoHours: "2h"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .forever: nil
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        case .twoHours: 2 * 60 * 60
        }
    }
}

@MainActor
final class SleepManager: ObservableObject {
    @Published private(set) var expiresAt: Date?
    @Published var duration: KeepAwakeDuration {
        didSet {
            UserDefaults.standard.set(duration.rawValue, forKey: "duration")
            if isActive && duration != oldValue {
                activate(for: duration.seconds)
            }
        }
    }

    @Published var keepDisplayAwake: Bool {
        didSet {
            UserDefaults.standard.set(keepDisplayAwake, forKey: "keepDisplayAwake")
            // Swap the assertion type in place, preserving any running countdown.
            if isActive {
                rearm()
            }
        }
    }

    @Published private var assertionID: IOPMAssertionID?
    private var expiryTimer: Timer?

    var isActive: Bool { assertionID != nil }

    init() {
        duration = UserDefaults.standard.string(forKey: "duration").flatMap(KeepAwakeDuration.init) ?? .forever
        keepDisplayAwake = UserDefaults.standard.object(forKey: "keepDisplayAwake") as? Bool ?? true

        // The expiry timer counts uptime, which pauses while the Mac sleeps, so re-arm it from the wall clock on wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.expiresAt != nil else { return }

                self.rearm()
            }
        }
    }

    func activate(for seconds: TimeInterval?) {
        deactivate()

        let type = keepDisplayAwake
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep
            : kIOPMAssertionTypePreventUserIdleSystemSleep

        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Sleepless is keeping this Mac awake" as CFString,
            &id
        )

        guard result == kIOReturnSuccess else { return }

        assertionID = id

        if let seconds {
            expiresAt = Date().addingTimeInterval(seconds)
            expiryTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.deactivate() }
            }
        }
    }

    func deactivate() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        if let assertionID {
            IOPMAssertionRelease(assertionID)
            self.assertionID = nil
        }
        expiresAt = nil
    }

    /// Re-arms with the wall-clock time left on the countdown, if any.
    private func rearm() {
        activate(for: expiresAt.map { max(0, $0.timeIntervalSinceNow) })
    }
}
