import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Preferences")
                .font(.custom("Avenir Next Demi Bold", size: 24))

            GroupBox("Scrobbling") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable scrobbling", isOn: Binding(
                        get: { scrobbleService.scrobblingEnabled },
                        set: { _ in scrobbleService.toggleScrobbling() }
                    ))

                    LabeledContent("Now Playing Delay", value: "\(scrobbleService.nowPlayingDelaySeconds)s")
                    LabeledContent("Retry Backoff (current)", value: "\(scrobbleService.retryDelaySeconds)s")
                }
                .padding(.top, 2)
            }

            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Session", value: scrobbleService.sessionStatus)
                    LabeledContent("Capabilities", value: scrobbleService.capabilitiesStatus)
                    LabeledContent("Backend", value: scrobbleService.backendName)
                }
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(20)
    }
}
