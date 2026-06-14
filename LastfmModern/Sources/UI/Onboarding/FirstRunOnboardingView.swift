import SwiftUI

struct FirstRunOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var isCompleted: Bool
    let onOpenSettings: () -> Void
    let onFinish: () -> Void

    @State private var selectedStep: OnboardingStep = .account
    @State private var username = ""
    @State private var password = ""
    @State private var isSigningIn = false

    private let steps = OnboardingStep.allCases

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Setup")
                    .font(.custom("Avenir Next Demi Bold", size: 22))
                    .padding(.bottom, 8)

                ForEach(steps) { step in
                    sidebarStepButton(step)
                }

                Spacer()
            }
            .padding(20)
            .frame(width: 250)
            .background(.bar)

            ZStack {
                AppBackdrop()

                VStack(alignment: .leading, spacing: 20) {
                    header

                    Group {
                        switch selectedStep {
                        case .account:
                            accountStep
                        case .sources:
                            sourcesStep
                        case .preferences:
                            preferencesStep
                        case .tour:
                            tourStep
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    footer
                }
                .padding(28)
                .frame(maxWidth: 820, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .interactiveDismissDisabled(!canDismiss)
        .frame(minWidth: 820, idealWidth: 920, minHeight: 560, idealHeight: 620)
    }

    private func sidebarStepButton(_ step: OnboardingStep) -> some View {
        Button {
            selectedStep = step
        } label: {
            HStack(spacing: 10) {
                Image(systemName: step.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22)
                Text(step.title)
                    .font(.custom("Avenir Next Medium", size: 13))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selectedStep == step ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if selectedStep == step {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(selectedStep.title, systemImage: selectedStep.systemImage)
                .font(.custom("Avenir Next Demi Bold", size: 28))
                .symbolRenderingMode(.hierarchical)

            Text(selectedStep.subtitle)
                .font(.custom("Avenir Next Medium", size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusPanel

            if !scrobbleService.isAuthenticated {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)

                    HStack(spacing: 10) {
                        Button {
                            signIn()
                        } label: {
                            Label(isSigningIn ? "Signing In" : "Sign In", systemImage: "person.badge.key")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSigningIn || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                        Button {
                            selectedStep = .sources
                        } label: {
                            Label("Configure Later", systemImage: "clock")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .appPanelStyle()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Connected as \(scrobbleService.sessionUsername ?? "Last.fm user")", systemImage: "checkmark.circle.fill")
                        .font(.custom("Avenir Next Demi Bold", size: 15))
                        .foregroundStyle(.green)

                    Text("The app will validate the stored session and refresh profile data automatically.")
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.secondary)
                }
                .appPanelStyle()
            }
        }
    }

    private var sourcesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            setupRow(
                title: "Now playing monitor",
                detail: scrobbleService.monitorStatus.isEmpty ? "Waiting for playback events" : scrobbleService.monitorStatus,
                systemImage: "waveform"
            )
            setupRow(
                title: "Queue persistence",
                detail: scrobbleService.queueFilePath.isEmpty ? "Queue path will be created on first write" : scrobbleService.queueFilePath,
                systemImage: "tray.full"
            )
            setupRow(
                title: "Network profile",
                detail: scrobbleService.backendName,
                systemImage: "network"
            )
        }
    }

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(
                get: { scrobbleService.scrobblingEnabled },
                set: { enabled in
                    if enabled != scrobbleService.scrobblingEnabled {
                        scrobbleService.toggleScrobbling()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Scrobbling")
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                    Text(scrobbleService.scrobblingEnabled ? "Tracks can be queued and submitted." : "Playback will be observed without submitting scrobbles.")
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .appPanelStyle()

            Button {
                onOpenSettings()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)

            Text("Proxy, launch-at-login, Dock visibility, and stored accounts live in Settings.")
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var tourStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            tourRow(title: "Queue", detail: "Review pending scrobbles before retry submission.", systemImage: "text.line.first.and.arrowtriangle.forward")
            tourRow(title: "Profile", detail: "Load profile, listening totals, loved tracks, and recent activity.", systemImage: "person.2.wave.2")
            tourRow(title: "Charts", detail: "Browse top artists across weekly, monthly, yearly, and overall windows.", systemImage: "list.number")
            tourRow(title: "Friends", detail: "Compare social listening activity and explore separation graphs.", systemImage: "person.3.sequence")
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Auth State", value: scrobbleService.isAuthenticated ? "Authenticated" : "Not authenticated")
            LabeledContent("Session", value: scrobbleService.sessionStatus)
            LabeledContent("Backend", value: scrobbleService.backendName)

            if let authError = scrobbleService.authError {
                Text(authError)
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.custom("Avenir Next Medium", size: 13))
        .appPanelStyle()
    }

    private var footer: some View {
        HStack {
            Button {
                goBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(selectedStep == steps.first)

            Spacer()

            if selectedStep == steps.last && requiresAccountRecovery {
                Button {
                    selectedStep = .account
                } label: {
                    Label("Back To Sign In", systemImage: "person.badge.key")
                }
                .buttonStyle(.borderedProminent)
            } else if canFinish {
                Button {
                    finish()
                } label: {
                    Label("Finish Setup", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    goForward()
                } label: {
                    Label(selectedStep == .account && !scrobbleService.isAuthenticated ? "Continue Without Account" : "Continue", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var canFinish: Bool {
        selectedStep == steps.last && !requiresAccountRecovery
    }

    private var canDismiss: Bool {
        canFinish
    }

    private var requiresAccountRecovery: Bool {
        !scrobbleService.isAuthenticated && scrobbleService.sessionStatus == "Session invalid"
    }

    private func setupRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 14))
                Text(detail)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
            }
        }
        .appPanelStyle()
    }

    private func tourRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 14))
                Text(detail)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .appPanelStyle()
    }

    private func signIn() {
        isSigningIn = true
        Task {
            await scrobbleService.signIn(username: username, password: password)
            isSigningIn = false
            if scrobbleService.isAuthenticated {
                selectedStep = .sources
            }
        }
    }

    private func goBack() {
        guard let index = steps.firstIndex(of: selectedStep), index > steps.startIndex else { return }
        selectedStep = steps[steps.index(before: index)]
    }

    private func goForward() {
        guard let index = steps.firstIndex(of: selectedStep), index < steps.index(before: steps.endIndex) else {
            finish()
            return
        }
        selectedStep = steps[steps.index(after: index)]
    }

    private func finish() {
        isCompleted = true
        onFinish()
        dismiss()
    }
}
