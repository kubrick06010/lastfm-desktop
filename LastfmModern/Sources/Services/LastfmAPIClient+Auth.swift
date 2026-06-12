import Foundation

extension LastfmAPIClient {
    func authenticate(username: String, password: String) async throws -> LastfmSession {
        var params: [String: String] = [
            "method": "auth.getMobileSession",
            "username": username,
            "password": password
        ]

        let payload = try await send(params: &params, cachePolicy: .none).payload
        guard
            let sessionData = payload["session"] as? [String: Any],
            let name = sessionData["name"] as? String,
            let key = sessionData["key"] as? String
        else {
            throw LastfmAPIError.invalidResponse
        }

        let newSession = LastfmSession(name: name, key: key)
        restoreSession(newSession)
        return newSession
    }

    func restoreSession(_ session: LastfmSession) {
        self.session = session
        isAuthenticated = true
    }

    func clearSession() {
        session = nil
        isAuthenticated = false
    }

    func validateSession() async throws -> LastfmSessionValidation {
        let sk = try requireSessionKey()
        var params: [String: String] = [
            "method": "user.getInfo",
            "sk": sk
        ]

        let response = try await send(
            params: &params,
            cachePolicy: .ttl(seconds: 300, staleFallbackSeconds: 86_400)
        )
        let payload = response.payload
        guard let user = payload["user"] as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }

        let subscriberRaw = (user["subscriber"] as? String) ?? (user["subscriber"] as? NSNumber)?.stringValue ?? "0"
        let isSubscriber = subscriberRaw == "1"
        let accountType = user["type"] as? String
        let capabilities = LastfmCapabilities(
            canScrobble: true,
            canUseRadio: isSubscriber,
            isSubscriber: isSubscriber,
            accountType: accountType
        )

        return LastfmSessionValidation(
            isValid: true,
            checkedAt: .now,
            fromCache: response.fromCache,
            capabilities: capabilities
        )
    }
}
