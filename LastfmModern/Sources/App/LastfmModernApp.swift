import SwiftUI
import AppKit

@main
struct LastfmModernApp: App {
    @StateObject private var scrobbleService = ScrobbleService()
    @Environment(\.openWindow) private var openWindow
    @AppStorage("ui.showDockIcon") private var showDockIcon = true

    var body: some Scene {
        WindowGroup("Last.fm modern", id: "main") {
            ContentView()
                .environmentObject(scrobbleService)
                .frame(minWidth: 760, minHeight: 560)
                .onAppear {
                    applyDockIconVisibility()
                }
                .onChange(of: showDockIcon) { _ in
                    applyDockIconVisibility()
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("Tools") {
                Button("Diagnostics") {
                    openWindow(id: "diagnostics")
                }
                .keyboardShortcut("d", modifiers: [.command, .option])

                Divider()

                Button(showDockIcon ? "Switch To Menu Bar Only" : "Show Dock Icon") {
                    toggleDockIconVisibility()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
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
                Button(showDockIcon ? "Switch to Menu Bar only" : "Show Dock icon") {
                    toggleDockIconVisibility()
                }

                Button("Open Last.fm modern") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Divider()

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

    private func toggleDockIconVisibility() {
        showDockIcon.toggle()
        applyDockIconVisibility()
    }

    private func applyDockIconVisibility() {
        // `.regular` shows Dock icon + app switcher presence.
        // `.accessory` keeps the app alive as menu-bar-focused without Dock icon.
        let targetPolicy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        guard NSApp.activationPolicy() != targetPolicy else { return }
        NSApp.setActivationPolicy(targetPolicy)
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

                        HStack(spacing: 10) {
                            Button("Retry now") {
                                Task { await scrobbleService.retryQueueNow() }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Clear queue") {
                                scrobbleService.clearQueue()
                            }
                            .buttonStyle(.bordered)
                            .disabled(scrobbleService.queuedScrobbles.isEmpty)
                        }
                        .padding(.top, 4)
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
