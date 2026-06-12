import Foundation
final class LastfmAPIClient: LastfmAPI {
    let isConfigured = true
    var isAuthenticated = false
    var sessionUsername: String? { session?.name }

    let config: LastfmAPIConfig
    let sessionProvider: () -> URLSession
    var session: LastfmSession?
    var endpointCache: [String: EndpointCacheEntry] = [:]
    let endpointCacheLock = NSLock()

    init(config: LastfmAPIConfig, sessionProvider: @escaping () -> URLSession = { .shared }) {
        self.config = config
        self.sessionProvider = sessionProvider
    }

}

struct EndpointResponse {
    let payload: [String: Any]
    let fromCache: Bool
}

struct EndpointCacheEntry {
    let data: Data
    let cachedAt: Date
    let expiresAt: Date
    let staleUntil: Date
}

enum EndpointCachePolicy {
    case none
    case ttl(seconds: TimeInterval, staleFallbackSeconds: TimeInterval)

    var shouldStore: Bool {
        switch self {
        case .none:
            return false
        case .ttl:
            return true
        }
    }

    var allowStaleFallback: Bool {
        switch self {
        case .none:
            return false
        case .ttl:
            return true
        }
    }

    var ttlSeconds: TimeInterval {
        switch self {
        case .none:
            return 0
        case let .ttl(seconds, _):
            return seconds
        }
    }

    var staleFallbackSeconds: TimeInterval {
        switch self {
        case .none:
            return 0
        case let .ttl(_, staleFallbackSeconds):
            return staleFallbackSeconds
        }
    }

    func useFreshCache(for entry: EndpointCacheEntry, now: Date) -> Bool {
        switch self {
        case .none:
            return false
        case .ttl:
            return entry.expiresAt >= now
        }
    }
}
