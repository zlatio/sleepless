import AppKit
import IOKit.pwr_mgt

enum KeepAwakeDuration: String, CaseIterable, Codable, Identifiable {
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
    /// The hold behind the popover's button and the CLI's `on`.
    static let manual = "manual"

    /// One reason to stay awake. It ends when `expiresAt` passes or `pid` exits, whichever comes first.
    struct Hold {
        let expiresAt: Date?
        let pid: pid_t?
        fileprivate let timer: Timer?
        fileprivate let exitSource: (any DispatchSourceProcess)?

        fileprivate func cancel() {
            timer?.invalidate()
            exitSource?.cancel()
        }
    }

    @Published private(set) var holds: [String: Hold] = [:]
    @Published var duration: KeepAwakeDuration {
        didSet {
            UserDefaults.standard.set(duration.rawValue, forKey: "duration")
            if let manual = holds[Self.manual], duration != oldValue {
                // Only a pid that has just exited can fail here, and its exit source ends the hold.
                try? hold(Self.manual, for: duration.seconds, pid: manual.pid)
            }
        }
    }

    @Published var keepDisplayAwake: Bool {
        didSet {
            UserDefaults.standard.set(keepDisplayAwake, forKey: "keepDisplayAwake")
            // Swap the assertion type in place. If the new one can't be created, the old one stays.
            if assertionID != nil && keepDisplayAwake != oldValue {
                try? createAssertion()
            }
        }
    }

    private var assertionID: IOPMAssertionID?

    var isActive: Bool { !holds.isEmpty }

    init() {
        duration = UserDefaults.standard.string(forKey: "duration").flatMap(KeepAwakeDuration.init) ?? .forever
        keepDisplayAwake = UserDefaults.standard.object(forKey: "keepDisplayAwake") as? Bool ?? true

        // Expiry timers count uptime, which pauses while the Mac sleeps, so re-arm them from the wall clock on wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }

                for (name, hold) in self.holds {
                    if let expiresAt = hold.expiresAt {
                        // Only a pid that exited during sleep can fail here, and its exit source ends the hold.
                        try? self.hold(name, for: max(0, expiresAt.timeIntervalSinceNow), pid: hold.pid)
                    }
                }
            }
        }
    }

    /// Adds the hold `name`, replacing any hold with that name.
    func hold(_ name: String, for seconds: TimeInterval?, pid: pid_t?) throws {
        if let pid, kill(pid, 0) == -1, errno == ESRCH {
            throw ControlError("No such process: \(pid)")
        }

        holds[name]?.cancel()
        if assertionID == nil {
            try createAssertion()
        }

        let timer = seconds.map { seconds in
            Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.release(name) }
            }
        }
        let exitSource = pid.map { pid in
            let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.release(name) }
            }
            source.resume()

            return source
        }
        holds[name] = Hold(
            expiresAt: seconds.map { Date(timeIntervalSinceNow: $0) },
            pid: pid,
            timer: timer,
            exitSource: exitSource
        )
    }

    /// Ends the hold `name` if it exists, and lets the Mac sleep once no holds are left.
    func release(_ name: String) {
        holds.removeValue(forKey: name)?.cancel()
        if holds.isEmpty, let assertionID {
            IOPMAssertionRelease(assertionID)
            self.assertionID = nil
        }
    }

    func releaseAll() {
        for name in holds.keys {
            release(name)
        }
    }

    /// Creates an assertion for the current display setting, then releases the one it replaces.
    private func createAssertion() throws {
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

        guard result == kIOReturnSuccess else {
            throw ControlError("Couldn't create the power assertion (IOReturn \(result))")
        }

        if let assertionID {
            IOPMAssertionRelease(assertionID)
        }
        assertionID = id
    }
}
