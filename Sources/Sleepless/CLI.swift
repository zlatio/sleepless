import Foundation

/// The `sleepless` command line. It runs as its own process and talks to the app through `ControlPort`.
enum CLI {
    private enum Command: String {
        case status, on, off, hold, release, run
        case claudeHook = "claude-hook"
    }

    static let usage = """
        Usage:
          sleepless status [--json]
          sleepless on [--for 15m|30m|1h|2h|forever] [--while PID] [--display|--no-display]
          sleepless off
          sleepless hold NAME (--while PID | --for 15m|30m|1h|2h) [--json]
          sleepless release NAME
          sleepless run [--name NAME] -- COMMAND [ARGS...]
          sleepless claude-hook PID
          sleepless --version

        The Mac stays awake while any hold exists. A hold ends when its time runs out or its PID exits.
        on starts the popover's own hold, named manual. off releases every hold.
        hold needs --while, --for, or both. claude-hook reads a Claude Code hook payload from stdin.

        Examples:
          sleepless hold build --while 4821    stay awake until process 4821 exits
          sleepless hold deploy --for 2h       stay awake for up to two hours
          sleepless run -- swift test          stay awake while the tests run
          sleepless status --json
        """

    /// The Sleepless.app this binary is in, found through any symlinks. Nil outside a bundle (`swift run`).
    private static var appURL: URL? {
        let app = Bundle.main.executableURL!.resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return app.pathExtension == "app" ? app : nil
    }

    static func run(_ arguments: [String]) -> Never {
        switch arguments[0] {
        case "-h", "--help":
            print(usage)
            exit(0)
        case "--version":
            let bundle = appURL.flatMap { Bundle(url: $0) }
            let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            print("Sleepless \(version ?? "(not in an app bundle)")")
            exit(0)
        default:
            break
        }

        guard let command = Command(rawValue: arguments[0]) else {
            FileHandle.standardError.write(Data((usage + "\n").utf8))
            exit(1)
        }

        do {
            let (argumentCount, allowedOptions): (ClosedRange<Int>, Set<String>) =
                switch command {
                case .status: (0...0, ["--json"])
                case .on: (0...0, ["--for", "--while", "--display", "--no-display"])
                case .off: (0...0, [])
                case .hold: (1...1, ["--for", "--while", "--json"])
                case .release: (1...1, [])
                case .run: (1...Int.max, ["--name"])
                case .claudeHook: (1...1, [])
                }
            var options: [String: String] = [:]
            var positional: [String] = []
            var rest = arguments.dropFirst()
            while let argument = rest.popFirst() {
                if argument == "--" {
                    positional += rest
                    break
                }
                if !argument.hasPrefix("-") {
                    positional.append(argument)
                } else if !allowedOptions.contains(argument) {
                    throw ControlError("\(command.rawValue) doesn't take \(argument)")
                } else if ["--for", "--while", "--name"].contains(argument) {
                    guard let value = rest.popFirst() else {
                        throw ControlError("\(argument) needs a value")
                    }

                    options[argument] = value
                } else {
                    options[argument] = ""
                }
            }

            guard argumentCount.contains(positional.count) else {
                throw ControlError("Wrong arguments for \(command.rawValue). See sleepless --help.")
            }

            let reply: Data?
            switch command {
            case .status:
                reply = try send(.status, launch: false)
            case .on:
                let keepDisplayAwake: Bool? =
                    options["--display"] != nil ? true : options["--no-display"] != nil ? false : nil
                reply = try send(
                    .on(
                        duration: try options["--for"].map { try parseDuration($0, allowForever: true) },
                        pid: try options["--while"].map(parsePID),
                        keepDisplayAwake: keepDisplayAwake
                    ),
                    launch: true
                )
            case .off:
                reply = try send(.off, launch: false)
            case .hold:
                guard options["--while"] != nil || options["--for"] != nil else {
                    throw ControlError("hold needs --while PID, --for DURATION, or both, so it can't last forever")
                }

                reply = try send(
                    .hold(
                        name: positional[0],
                        duration: try options["--for"].map { try parseDuration($0, allowForever: false) },
                        pid: try options["--while"].map(parsePID)
                    ),
                    launch: true
                )
            case .release:
                reply = try send(.release(name: positional[0], pid: nil), launch: false)
            case .run:
                let name = options["--name"] ?? URL(fileURLWithPath: positional[0]).lastPathComponent
                // The hold watches this process, so it also ends if the CLI is killed before it releases.
                try send(.hold(name: name, duration: nil, pid: getpid()), launch: true)
                let child = try Process.run(URL(fileURLWithPath: "/usr/bin/env"), arguments: positional)
                child.waitUntilExit()
                // With our pid, this leaves the hold alone if another run has since taken over the name.
                _ = try? send(.release(name: name, pid: getpid()), launch: false)
                // Like a shell, report a child killed by signal N as 128 + N.
                let code = child.terminationStatus
                exit(child.terminationReason == .uncaughtSignal ? 128 + code : code)
            case .claudeHook:
                // Prints nothing: Claude Code adds a UserPromptSubmit hook's stdout to the conversation.
                let pid = try parsePID(positional[0])
                let name = "claude-\(pid)"
                let input = try FileHandle.standardInput.readToEnd() ?? Data()
                let payload = try JSONSerialization.jsonObject(with: input) as? [String: Any]
                switch payload?["hook_event_name"] as? String {
                case "UserPromptSubmit":
                    try send(.hold(name: name, duration: nil, pid: pid), launch: true)
                // Stop fires at the end of every turn, even while background tasks are still running.
                case "Stop" where (payload?["background_tasks"] as? [Any] ?? []).isEmpty, "SessionEnd":
                    try send(.release(name: name, pid: nil), launch: false)
                default:
                    break
                }
                exit(0)
            }

            guard let reply else {
                let status = ControlPort.Status(version: nil, active: false, keepDisplayAwake: nil, holds: [])
                print(
                    options["--json"] != nil
                        ? String(decoding: status.json, as: UTF8.self) : "Sleeping normally (Sleepless isn't running)"
                )
                exit(0)
            }

            if options["--json"] != nil {
                print(String(decoding: reply, as: UTF8.self))
                exit(0)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let status = try decoder.decode(ControlPort.Status.self, from: reply)
            let display = status.keepDisplayAwake == true ? "stays on" : "can sleep"
            print(status.active ? "Awake, display \(display)" : "Sleeping normally")
            let width = status.holds.map(\.name.count).max() ?? 0
            for hold in status.holds {
                let until = hold.expiresAt.map { "until \($0.formatted(date: .omitted, time: .shortened))" }
                let details = [until, hold.pid.map { "while pid \($0)" }].compactMap { $0 }.joined(separator: ", ")
                let name = hold.name.padding(toLength: width, withPad: " ", startingAt: 0)
                print("  \(name)  \(details.isEmpty ? "no time limit" : details)")
            }
            exit(0)
        } catch {
            let message = (error as? ControlError)?.error ?? error.localizedDescription
            FileHandle.standardError.write(Data("sleepless: \(message)\n".utf8))
            exit(1)
        }
    }

    /// Sends `request` to the running app and returns its status JSON, or nil when the app isn't running.
    /// With `launch`, it first starts the app this binary belongs to.
    @discardableResult
    private static func send(_ request: ControlPort.Request, launch: Bool) throws -> Data? {
        var port = CFMessagePortCreateRemote(nil, ControlPort.name as CFString)
        if port == nil && launch {
            guard let app = appURL else {
                throw ControlError("Sleepless isn't running, and this binary isn't inside Sleepless.app to start it")
            }

            // -g keeps the app in the background, so a hook doesn't take focus from the terminal.
            try Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: ["-g", app.path]).waitUntilExit()
            let deadline = Date(timeIntervalSinceNow: 5)
            while port == nil && Date() < deadline {
                usleep(100_000)
                port = CFMessagePortCreateRemote(nil, ControlPort.name as CFString)
            }

            guard port != nil else {
                throw ControlError("Started Sleepless, but it didn't answer within 5 seconds")
            }
        }

        guard let port else { return nil }

        var reply: Unmanaged<CFData>?
        let result = CFMessagePortSendRequest(
            port,
            0,
            try JSONEncoder().encode(request) as CFData,
            5,
            5,
            CFRunLoopMode.defaultMode.rawValue,
            &reply
        )

        guard result == kCFMessagePortSuccess, let reply else {
            throw ControlError("Sleepless didn't answer (CFMessagePort error \(result))")
        }

        let data = reply.takeRetainedValue() as Data

        if let failure = try? JSONDecoder().decode(ControlError.self, from: data) {
            throw failure
        }

        return data
    }

    private static func parsePID(_ value: String) throws -> pid_t {
        guard let pid = pid_t(value), pid > 0 else {
            throw ControlError("Not a process ID: \(value)")
        }

        return pid
    }

    private static func parseDuration(_ value: String, allowForever: Bool) throws -> KeepAwakeDuration {
        let presets = KeepAwakeDuration.allCases.filter { allowForever || $0 != .forever }
        let name = { (preset: KeepAwakeDuration) in preset == .forever ? "forever" : preset.label }

        guard let duration = presets.first(where: { name($0) == value }) else {
            throw ControlError("--for takes \(presets.map(name).joined(separator: ", "))")
        }

        return duration
    }
}
