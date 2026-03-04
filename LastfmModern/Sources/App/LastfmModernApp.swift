import SwiftUI

@main
struct LastfmModernApp: App {
    @StateObject private var scrobbleService = ScrobbleService()

    var body: some Scene {
        WindowGroup("LastfmModern") {
            ContentView()
                .environmentObject(scrobbleService)
                .frame(minWidth: 980, minHeight: 620)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Queue Current Track") {
                    scrobbleService.queueCurrentTrack()
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])

                Button("Submit Queue") {
                    Task { await scrobbleService.submitQueued() }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("Last.fm", systemImage: "music.note") {
            NowPlayingView(compact: true)
                .environmentObject(scrobbleService)
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
