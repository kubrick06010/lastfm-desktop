import Foundation

enum OnboardingStep: String, CaseIterable, Identifiable {
    case account
    case sources
    case preferences
    case tour

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account:
            return "Connect Last.fm"
        case .sources:
            return "Playback Sources"
        case .preferences:
            return "Scrobbling Defaults"
        case .tour:
            return "Workspace Tour"
        }
    }

    var subtitle: String {
        switch self {
        case .account:
            return "Sign in so scrobbles, profile data, and social context can sync."
        case .sources:
            return "Confirm that the app is listening for local playback changes."
        case .preferences:
            return "Choose the startup behavior that matches how you use macOS."
        case .tour:
            return "See where queue, profile, charts, and friends live."
        }
    }

    var systemImage: String {
        switch self {
        case .account:
            return "person.crop.circle.badge.checkmark"
        case .sources:
            return "music.note.tv"
        case .preferences:
            return "slider.horizontal.3"
        case .tour:
            return "rectangle.3.group.bubble.left"
        }
    }
}
