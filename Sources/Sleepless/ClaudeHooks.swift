import Foundation

/// The Claude Code hooks in ~/.claude/settings.json that hold the Mac awake while a session works.
enum ClaudeHooks {
    enum Status: Equatable {
        case setUp
        case notSetUp(String)
    }

    static let events = ["UserPromptSubmit", "Stop", "SessionEnd"]
    static let settingsURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json")

    /// Set up means every event runs `claude-hook` through a Sleepless binary that still exists.
    static func status() -> Status {
        let settings: [String: Any]
        do {
            settings = try readSettings()
        } catch {
            return .notSetUp(error.localizedDescription)
        }

        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        var missing: [String] = []
        for event in events {
            let paths = (hooks[event] as? [[String: Any]] ?? [])
                .flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
                .compactMap { ($0["command"] as? String).flatMap(sleeplessPath) }
            if paths.isEmpty {
                missing.append(event)
            } else if let gone = paths.first(where: { !FileManager.default.isExecutableFile(atPath: $0) }) {
                return .notSetUp("Points to \(gone), which doesn't exist")
            }
        }

        if missing.count == events.count {
            return .notSetUp("Not set up")
        }

        if !missing.isEmpty {
            return .notSetUp("Missing for \(missing.joined(separator: ", "))")
        }

        return .setUp
    }

    /// Points all three events at this app's binary. Replaces older Sleepless entries, keeps every other hook,
    /// and copies the previous file to settings.json.sleepless-backup.
    static func install() throws {
        var settings = try readSettings()
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let command = "\"\(Bundle.main.executablePath!)\" claude-hook $PPID"
        for event in events {
            var groups = (hooks[event] as? [[String: Any]] ?? []).compactMap { group -> [String: Any]? in
                var group = group
                let others = (group["hooks"] as? [[String: Any]] ?? [])
                    .filter { ($0["command"] as? String).flatMap(sleeplessPath) == nil }

                guard !others.isEmpty else { return nil }

                group["hooks"] = others

                return group
            }
            groups.append(["hooks": [["type": "command", "command": command]]])
            hooks[event] = groups
        }
        settings["hooks"] = hooks

        // Write through a symlink, as with a settings.json kept in a dotfiles repo.
        let url = settingsURL.resolvingSymlinksInPath()
        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        if FileManager.default.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("sleepless-backup")
            try? FileManager.default.removeItem(at: backup)
            try FileManager.default.copyItem(at: url, to: backup)
        } else {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        try (data + Data("\n".utf8)).write(to: url, options: .atomic)
    }

    /// The settings as a dictionary, empty when the file doesn't exist yet.
    private static func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL))

        guard let settings = object as? [String: Any] else {
            throw ControlError("~/.claude/settings.json isn't a JSON object")
        }

        return settings
    }

    /// The binary in a Sleepless `claude-hook` command, quoted or not. Other tools have their own `claude-hook`
    /// scripts, so the binary has to be named Sleepless.
    private static func sleeplessPath(of command: String) -> String? {
        guard let match = command.firstMatch(of: /^"?([^"]*\/[Ss]leepless)"? claude-hook\b/) else { return nil }

        return (String(match.1) as NSString).expandingTildeInPath
    }
}

extension ControlError: LocalizedError {
    var errorDescription: String? { error }
}
