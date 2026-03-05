import SwiftUI

@main
struct LastfmModernApp: App {
    @StateObject private var scrobbleService = ScrobbleService()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("LastfmModern") {
            ContentView()
                .environmentObject(scrobbleService)
                .frame(minWidth: 760, minHeight: 560)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("Tools") {
                Button("Diagnostics") {
                    openWindow(id: "diagnostics")
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
            }
        }

        Window("Diagnostics", id: "diagnostics") {
            DiagnosticsView()
                .environmentObject(scrobbleService)
                .frame(minWidth: 580, minHeight: 460)
        }
        .defaultSize(width: 720, height: 560)

        MenuBarExtra("Last.fm", systemImage: "music.note") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable scrobbling", isOn: Binding(
                    get: { scrobbleService.scrobblingEnabled },
                    set: { enabled in
                        if enabled != scrobbleService.scrobblingEnabled {
                            scrobbleService.toggleScrobbling()
                        }
                    }
                ))
            }
            .padding()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(scrobbleService)
                .frame(width: 480, height: 280)
        }
    }
}

private struct DiagnosticsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Diagnostics")
                    .font(.custom("Avenir Next Demi Bold", size: 28))

                GroupBox("Session") {
                    VStack(alignment: .leading, spacing: 8) {
                        diagnosticsRow("Backend", scrobbleService.backendName)
                        diagnosticsRow("Auth", scrobbleService.isAuthenticated ? "Authenticated" : "Not authenticated")
                        diagnosticsRow("Session", scrobbleService.sessionStatus)
                        diagnosticsRow("Capabilities", scrobbleService.capabilitiesStatus)
                        diagnosticsRow("Validation Source", scrobbleService.validationSource)
                    }
                    .font(.custom("Avenir Next Medium", size: 12))
                    .padding(.top, 2)
                }

                GroupBox("Playback") {
                    VStack(alignment: .leading, spacing: 8) {
                        diagnosticsRow("Monitor", scrobbleService.monitorStatus)
                        diagnosticsRow("State", scrobbleService.playbackState)
                        diagnosticsRow("Elapsed", "\(Int(scrobbleService.elapsedForCurrentTrack))s")
                        diagnosticsRow("Threshold", "\(Int(scrobbleService.scrobbleThreshold))s")
                        diagnosticsRow("Now Playing Delay", "\(scrobbleService.nowPlayingDelaySeconds)s")
                        diagnosticsRow("Player Events", "\(scrobbleService.playerEventCount)")
                    }
                    .font(.custom("Avenir Next Medium", size: 12))
                    .padding(.top, 2)
                }

                GroupBox("Queue And Retry") {
                    VStack(alignment: .leading, spacing: 8) {
                        diagnosticsRow("Queued", "\(scrobbleService.queuedScrobbles.count)")
                        diagnosticsRow("Submit Attempts", "\(scrobbleService.queueSubmitAttempts)")
                        diagnosticsRow("Submit Failures", "\(scrobbleService.queueSubmitFailures)")
                        diagnosticsRow("Retry Delay", "\(scrobbleService.retryDelaySeconds)s")
                        diagnosticsRow("Retry Scheduled", scrobbleService.isRetryScheduled ? "Yes" : "No")
                        diagnosticsRow("Queue File", scrobbleService.queueFilePath)
                        if let lastSubmittedAt = scrobbleService.lastSubmittedAt {
                            diagnosticsRow("Last Submit", lastSubmittedAt.formatted())
                        }
                        if let nextRetryAt = scrobbleService.nextRetryAt {
                            diagnosticsRow("Next Retry", nextRetryAt.formatted())
                        }
                    }
                    .font(.custom("Avenir Next Medium", size: 12))
                    .padding(.top, 2)
                }

                if let apiError = scrobbleService.lastAPIError {
                    GroupBox("Last API Error") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(apiError)
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.red)
                            if let hint = scrobbleService.lastRecoveryHint {
                                Text(hint)
                                    .font(.custom("Avenir Next Regular", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(20)
        }
    }

    private func diagnosticsRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
