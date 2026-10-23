import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var manager: SleepManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            toggleButton
            durationPicker
            displayToggle
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 280)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        manager.isActive
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.secondary.opacity(0.18))
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: manager.isActive ? "cup.and.saucer.fill" : "moon.zzz.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(manager.isActive ? .white : .secondary)
            }
            .animation(.easeInOut(duration: 0.2), value: manager.isActive)

            VStack(alignment: .leading, spacing: 1) {
                Text("Sleepless")
                    .font(.system(size: 14, weight: .semibold))
                statusLine
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        let manual = manager.holds[SleepManager.manual]
        let others = manager.holds.keys.filter { $0 != SleepManager.manual }.sorted()
        let keptOnBy = others.count == 1 ? others[0] : "\(others.count) tasks"
        Group {
            if let expiresAt = manual?.expiresAt {
                Text("Awake · \(Text(expiresAt, style: .timer)) left")
                    .foregroundStyle(.orange)
            } else if manual != nil {
                Text("Awake indefinitely")
                    .foregroundStyle(.orange)
            } else if !others.isEmpty {
                Text("Awake · kept on by \(keptOnBy)")
                    .foregroundStyle(.orange)
            } else {
                Text("Sleeping normally")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, weight: .medium))
        if manual != nil && !others.isEmpty {
            Text("Also kept on by \(keptOnBy)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var toggleButton: some View {
        Button {
            if manager.isActive {
                manager.releaseAll()
            } else {
                try? manager.hold(SleepManager.manual, for: manager.duration.seconds, pid: nil)
            }
        } label: {
            Text(manager.isActive ? "Let My Mac Sleep" : "Keep My Mac Awake")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    manager.isActive
                        ? AnyShapeStyle(Color.secondary.opacity(0.18))
                        : AnyShapeStyle(LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .foregroundStyle(manager.isActive ? Color.primary : .white)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: manager.isActive)
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("DURATION")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.tertiary)
                .kerning(0.5)
            Picker("Duration", selection: $manager.duration) {
                ForEach(KeepAwakeDuration.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var displayToggle: some View {
        Toggle(isOn: $manager.keepDisplayAwake) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Keep display on")
                    .font(.system(size: 12))
                Text("Off lets the screen dim while the Mac stays awake")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }

    private var footer: some View {
        HStack {
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                Text("v\(version)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }
}
