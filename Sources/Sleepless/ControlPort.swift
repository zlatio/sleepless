import Foundation

/// A failure with a message for the user. The app sends it back as `{"error": "..."}`.
struct ControlError: Error, Codable {
    let error: String

    init(_ error: String) {
        self.error = error
    }
}

/// The JSON messages between the CLI and the running app, sent over a `CFMessagePort`.
enum ControlPort {
    static let name = "dev.playground.sleepless.control"

    enum Request: Codable {
        case status
        case on(duration: KeepAwakeDuration?, pid: pid_t?, keepDisplayAwake: Bool?)
        case off
        case hold(name: String, duration: KeepAwakeDuration?, pid: pid_t?)
        /// With a `pid`, only releases the hold if it is still tied to that process.
        case release(name: String, pid: pid_t?)
    }

    /// The app's reply to every successful request. The CLI's `--json` output prints it as is.
    struct Status: Codable {
        struct Hold: Codable {
            let name: String
            let expiresAt: Date?
            let pid: pid_t?

            // Synthesized encoding leaves out nil values, but the format spells them as null.
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(name, forKey: .name)
                try container.encode(expiresAt, forKey: .expiresAt)
                try container.encode(pid, forKey: .pid)
            }
        }

        /// Nil when the app has no bundle (`swift run`), or the CLI found no app running.
        let version: String?
        let active: Bool
        let keepDisplayAwake: Bool?
        let holds: [Hold]

        var json: Data {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .sortedKeys

            return try! encoder.encode(self)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(version, forKey: .version)
            try container.encode(active, forKey: .active)
            try container.encode(keepDisplayAwake, forKey: .keepDisplayAwake)
            try container.encode(holds, forKey: .holds)
        }
    }

    /// Registers the app's end of the port on the main run loop.
    /// Returns false when another instance already owns the name.
    @MainActor
    static func listen(for manager: SleepManager) -> Bool {
        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(manager).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        // A C callback can't capture anything, so the manager comes in through `info`.
        let callback: CFMessagePortCallBack = { _, _, data, info in
            let reply = MainActor.assumeIsolated { () -> Data in
                let manager = Unmanaged<SleepManager>.fromOpaque(info!).takeUnretainedValue()
                do {
                    switch try JSONDecoder().decode(Request.self, from: data.map { $0 as Data } ?? Data()) {
                    case .status:
                        break
                    case .on(let duration, let pid, let keepDisplayAwake):
                        if let keepDisplayAwake {
                            manager.keepDisplayAwake = keepDisplayAwake
                        }
                        if let duration {
                            manager.duration = duration
                        }
                        try manager.hold(SleepManager.manual, for: manager.duration.seconds, pid: pid)
                    case .off:
                        manager.releaseAll()
                    case .hold(let name, let duration, let pid):
                        try manager.hold(name, for: duration?.seconds, pid: pid)
                    case .release(let name, let pid):
                        if pid == nil || manager.holds[name]?.pid == pid {
                            manager.release(name)
                        }
                    }

                    return Status(
                        version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                        active: manager.isActive,
                        keepDisplayAwake: manager.keepDisplayAwake,
                        holds: manager.holds.sorted { $0.key < $1.key }.map {
                            Status.Hold(name: $0.key, expiresAt: $0.value.expiresAt, pid: $0.value.pid)
                        }
                    ).json
                } catch {
                    let failure = error as? ControlError ?? ControlError("Bad request: \(error)")

                    return try! JSONEncoder().encode(failure)
                }
            }

            return Unmanaged.passRetained(reply as CFData)
        }
        let port = CFMessagePortCreateLocal(nil, name as CFString, callback, &context, nil)

        guard let port else { return false }

        CFRunLoopAddSource(CFRunLoopGetMain(), CFMessagePortCreateRunLoopSource(nil, port, 0), .commonModes)

        return true
    }
}
