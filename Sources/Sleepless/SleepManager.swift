import Foundation
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
    @Published private(set) var isActive = false
    @Published private(set) var expiresAt: Date?
    @Published var keepDisplayAwake = true {
        didSet {
            guard isActive else { return }
            // Swap the assertion type in place, preserving any running countdown.
            let remaining = expiresAt.map { max(0, $0.timeIntervalSinceNow) }
            activate(for: remaining)
        }
    }

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var expiryTimer: Timer?

    func activate(for duration: TimeInterval?) {
        releaseAssertion()

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
        hasAssertion = true
        isActive = true

        if let duration {
            expiresAt = Date().addingTimeInterval(duration)
            expiryTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.deactivate() }
            }
        } else {
            expiresAt = nil
        }
    }

    func deactivate() {
        releaseAssertion()
        isActive = false
        expiresAt = nil
    }

    private func releaseAssertion() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
        }
    }
}
