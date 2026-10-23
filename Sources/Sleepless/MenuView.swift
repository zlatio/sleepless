import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var manager: SleepManager
    @State private var duration: KeepAwakeDuration = .forever

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

    private var statusLine: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Group {
                if manager.isActive, let expiresAt = manager.expiresAt {
                    Text("Awake · \(remainingString(until: expiresAt)) left")
                        .foregroundStyle(.orange)
                } else if manager.isActive {
                    Text("Awake indefinitely")
                        .foregroundStyle(.orange)
                } else {
                    Text("Sleeping normally")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 11, weight: .medium))
        }
    }

    private var toggleButton: some View {
        Button {
            if manager.isActive {
                manager.deactivate()
            } else {
                manager.activate(for: duration.seconds)
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
            Picker("Duration", selection: $duration) {
                ForEach(KeepAwakeDuration.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: duration) { _, newValue in
                if manager.isActive {
                    manager.activate(for: newValue.seconds)
                }
            }
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
            Text("v1.0")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private func remainingString(until date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSinceNow.rounded()))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
