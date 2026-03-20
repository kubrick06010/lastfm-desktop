import SwiftUI

private enum PreferencesSection: String, CaseIterable, Identifiable {
    case general = "General"
    case accounts = "Accounts"
    case network = "Network"
    case advanced = "Advanced"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .accounts: return "person.crop.circle.badge.checkmark"
        case .network: return "network"
        case .advanced: return "gearshape.2"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Startup and app behaviour"
        case .accounts:
            return "Stored Last.fm sessions"
        case .network:
            return "Proxy and connectivity"
        case .advanced:
            return "Operational status"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @EnvironmentObject private var launchAtLoginController: LaunchAtLoginController
    @EnvironmentObject private var proxySettingsController: ProxySettingsController

    @State private var selectedSection: PreferencesSection? = .general
    @State private var username = ""
    @State private var password = ""
    @State private var proxyPortText = ""

    var body: some View {
        NavigationSplitView {
            List(PreferencesSection.allCases, selection: $selectedSection) { section in
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(section.rawValue)
                            .font(.custom("Avenir Next Demi Bold", size: 13))
                        Text(section.subtitle)
                            .font(.custom("Avenir Next Regular", size: 11))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: section.symbol)
                }
                .tag(section)
                .padding(.vertical, 3)
            }
            .listStyle(.sidebar)
            .navigationTitle("Preferences")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
        } detail: {
            ScrollView {
                Group {
                    switch selectedSection ?? .general {
                    case .general:
                        generalPane
                    case .accounts:
                        accountsPane
                    case .network:
                        networkPane
                    case .advanced:
                        advancedPane
                    }
                }
                .padding(24)
            }
            .background(Color.clear)
        }
        .task {
            launchAtLoginController.refreshStatus()
            proxySettingsController.reload()
            proxyPortText = proxySettingsController.settings.port.map(String.init) ?? ""
        }
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeader(
                title: "General",
                subtitle: "Core app behavior that should stay easy to reach."
            )

            GroupBox("Scrobbling") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable scrobbling", isOn: Binding(
                        get: { scrobbleService.scrobblingEnabled },
                        set: { _ in scrobbleService.toggleScrobbling() }
                    ))

                    LabeledContent("Now Playing Delay", value: "\(scrobbleService.nowPlayingDelaySeconds)s")
                    LabeledContent("Retry Backoff (current)", value: "\(scrobbleService.retryDelaySeconds)s")
                }
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }

            GroupBox("Startup") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: Binding(
                        get: { launchAtLoginController.isEnabled },
                        set: { enabled in
                            Task { await launchAtLoginController.setEnabled(enabled) }
                        }
                    ))
                    .disabled(launchAtLoginController.isApplyingChange)

                    Text("If Dock icon is hidden, the app starts silently in the menu bar on login.")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)

                    LabeledContent("Login Item", value: launchAtLoginController.statusDescription)
                }
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }
        }
    }

    private var accountsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeader(
                title: "Accounts",
                subtitle: "Switch or store multiple Last.fm sessions without opening the main app tabs."
            )

            GroupBox("Stored Accounts") {
                VStack(alignment: .leading, spacing: 12) {
                    if scrobbleService.storedAccounts.isEmpty {
                        Text("No stored accounts yet.")
                            .font(.custom("Avenir Next Regular", size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scrobbleService.storedAccounts, id: \.name) { session in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(session.name)
                                            .font(.custom("Avenir Next Demi Bold", size: 13))
                                        if session.name.caseInsensitiveCompare(scrobbleService.sessionUsername ?? "") == .orderedSame {
                                            Text("Active")
                                                .font(.custom("Avenir Next Demi Bold", size: 10))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                        }
                                    }
                                    Text("Stored session")
                                        .font(.custom("Avenir Next Regular", size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Use") {
                                    Task { await scrobbleService.switchAccount(username: session.name) }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button(role: .destructive) {
                                    Task { await scrobbleService.removeAccount(username: session.name) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            if session.name != scrobbleService.storedAccounts.last?.name {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }

            GroupBox("Add Or Refresh Session") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)

                    HStack {
                        Button("Sign In") {
                            Task {
                                await scrobbleService.signIn(username: username, password: password)
                                if scrobbleService.authError == nil {
                                    password = ""
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Remove Current") {
                            if let current = scrobbleService.sessionUsername {
                                Task { await scrobbleService.removeAccount(username: current) }
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(scrobbleService.sessionUsername == nil)
                    }

                    if let authError = scrobbleService.authError {
                        Text(authError)
                            .font(.custom("Avenir Next Regular", size: 12))
                            .foregroundStyle(.red)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }
        }
    }

    private var networkPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeader(
                title: "Network",
                subtitle: "Corporate-friendly proxy controls applied centrally to Last.fm requests."
            )

            GroupBox("Proxy") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Proxy Mode", selection: Binding(
                        get: { proxySettingsController.settings.mode },
                        set: { mode in
                            proxySettingsController.settings.mode = mode
                            proxySettingsController.save()
                        }
                    )) {
                        ForEach(ProxyMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if proxySettingsController.settings.usesManualProxy {
                        HStack(spacing: 12) {
                            TextField("Host", text: Binding(
                                get: { proxySettingsController.settings.host },
                                set: { value in
                                    proxySettingsController.settings.host = value
                                    proxySettingsController.save()
                                }
                            ))

                            TextField("Port", text: Binding(
                                get: { proxyPortText },
                                set: { value in
                                    proxyPortText = value
                                    proxySettingsController.settings.port = Int(value)
                                    proxySettingsController.save()
                                }
                            ))
                            .frame(width: 90)
                        }

                        TextField("Username (optional)", text: Binding(
                            get: { proxySettingsController.settings.username },
                            set: { value in
                                proxySettingsController.settings.username = value
                                proxySettingsController.save()
                            }
                        ))

                        SecureField("Password (optional)", text: Binding(
                            get: { proxySettingsController.settings.password },
                            set: { value in
                                proxySettingsController.settings.password = value
                                proxySettingsController.save()
                            }
                        ))
                    }

                    Text(proxySettingsController.statusDescription)
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
                .textFieldStyle(.roundedBorder)
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }
        }
    }

    private var advancedPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeader(
                title: "Advanced",
                subtitle: "Operational state and backend detail. Keep this out of the day-to-day surface area."
            )

            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Backend", value: scrobbleService.backendName)
                    LabeledContent("Auth State", value: scrobbleService.isAuthenticated ? "Authenticated" : "Not authenticated")
                    LabeledContent("Session", value: scrobbleService.sessionStatus)
                    LabeledContent("Capabilities", value: scrobbleService.capabilitiesStatus)
                    LabeledContent("Validation", value: scrobbleService.validationSource)
                }
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }

            if let lastError = launchAtLoginController.lastErrorMessage {
                GroupBox("Warnings") {
                    Text(lastError)
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func preferencesHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 24))
            Text(subtitle)
                .font(.custom("Avenir Next Regular", size: 13))
                .foregroundStyle(.secondary)
        }
    }
}
