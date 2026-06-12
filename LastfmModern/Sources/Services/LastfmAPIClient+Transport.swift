import Foundation

extension LastfmAPIClient {
    func users(from value: Any?) -> [[String: Any]] {
        if let array = value as? [[String: Any]] {
            return array
        }
        if let single = value as? [String: Any] {
            return [single]
        }
        return []
    }

    func tagNames(from value: Any?) -> [String] {
        users(from: value).compactMap { firstString($0["name"]) }
    }

    func dateFromUnix(_ value: String?) -> Date? {
        guard let value, let unix = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: unix)
    }

    func requireSessionKey() throws -> String {
        guard let key = session?.key else {
            throw LastfmAPIError.missingSession
        }
        return key
    }

    func requireSessionName() throws -> String {
        guard let name = session?.name, !name.isEmpty else {
            throw LastfmAPIError.missingSession
        }
        return name
    }

    func send(
        params: inout [String: String],
        cachePolicy: EndpointCachePolicy = .none
    ) async throws -> EndpointResponse {
        let originalParams = params
        let cacheKey = endpointCacheKey(params: originalParams)
        if let entry = cachedEntry(for: cacheKey), cachePolicy.useFreshCache(for: entry, now: .now) {
            return try EndpointResponse(payload: parsePayload(entry.data), fromCache: true)
        }

        params["api_key"] = config.apiKey
        params["api_sig"] = signature(for: params)

        var bodyParams = params
        bodyParams["format"] = "json"

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded(bodyParams).data(using: .utf8)

        do {
            let (data, _) = try await activeURLSession.data(for: request)
            let payload = try parsePayload(data)

            if let code = parseErrorCode(payload["error"]) {
                let message = payload["message"] as? String ?? "Unknown error"
                throw mapAPIError(code: code, message: message)
            }

            if cachePolicy.shouldStore {
                let entry = EndpointCacheEntry(
                    data: data,
                    cachedAt: .now,
                    expiresAt: Date().addingTimeInterval(cachePolicy.ttlSeconds),
                    staleUntil: Date().addingTimeInterval(cachePolicy.staleFallbackSeconds)
                )
                setCachedEntry(entry, for: cacheKey)
            }
            return EndpointResponse(payload: payload, fromCache: false)
        } catch {
            if error is CancellationError {
                throw error
            }
            if cachePolicy.allowStaleFallback,
               let entry = cachedEntry(for: cacheKey),
               entry.staleUntil >= Date() {
                return try EndpointResponse(payload: parsePayload(entry.data), fromCache: true)
            }
            if let error = error as? LastfmAPIError {
                throw error
            }
            if let error = error as? URLError {
                switch error.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                    throw LastfmAPIError.networkUnavailable
                default:
                    throw LastfmAPIError.transport
                }
            }
            throw LastfmAPIError.transport
        }
    }

    func sendPublicRead(
        params: [String: String],
        cachePolicy: EndpointCachePolicy = .none
    ) async throws -> EndpointResponse {
        let cacheKey = "public|" + endpointCacheKey(params: params)
        if let entry = cachedEntry(for: cacheKey), cachePolicy.useFreshCache(for: entry, now: .now) {
            return try EndpointResponse(payload: parsePayload(entry.data), fromCache: true)
        }

        var queryItems = params
        queryItems["api_key"] = config.apiKey
        queryItems["format"] = "json"

        var components = URLComponents(url: config.endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
            .sorted(by: { $0.key < $1.key })
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else {
            throw LastfmAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await activeURLSession.data(for: request)
            let payload = try parsePayload(data)

            if let code = parseErrorCode(payload["error"]) {
                let message = payload["message"] as? String ?? "Unknown error"
                throw mapAPIError(code: code, message: message)
            }

            if cachePolicy.shouldStore {
                let entry = EndpointCacheEntry(
                    data: data,
                    cachedAt: .now,
                    expiresAt: Date().addingTimeInterval(cachePolicy.ttlSeconds),
                    staleUntil: Date().addingTimeInterval(cachePolicy.staleFallbackSeconds)
                )
                setCachedEntry(entry, for: cacheKey)
            }
            return EndpointResponse(payload: payload, fromCache: false)
        } catch {
            if error is CancellationError {
                throw error
            }
            if cachePolicy.allowStaleFallback,
               let entry = cachedEntry(for: cacheKey),
               entry.staleUntil >= Date() {
                return try EndpointResponse(payload: parsePayload(entry.data), fromCache: true)
            }
            if let error = error as? LastfmAPIError {
                throw error
            }
            if let error = error as? URLError {
                switch error.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                    throw LastfmAPIError.networkUnavailable
                default:
                    throw LastfmAPIError.transport
                }
            }
            throw LastfmAPIError.transport
        }
    }

    func parsePayload(_ data: Data) throws -> [String: Any] {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }
        return payload
    }

    func mapAPIError(code: Int, message: String) -> LastfmAPIError {
        switch code {
        case 4:
            return .invalidCredentials
        case 9:
            return .invalidSession
        case 29:
            return .rateLimited(retryAfter: nil)
        default:
            return .api(code: code, message: message)
        }
    }

    func parseErrorCode(_ value: Any?) -> Int? {
        if let code = value as? Int {
            return code
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let text = value as? String {
            return Int(text)
        }
        return nil
    }

    func firstString(_ value: Any?) -> String? {
        if let text = value as? String, !text.isEmpty {
            return text
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let dict = value as? [String: Any] {
            if let text = dict["#text"] as? String, !text.isEmpty {
                return text
            }
            if let text = dict["name"] as? String, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    func htmlDecodedString(_ raw: String) -> String {
        guard let data = "<span>\(raw)</span>".data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return raw
        }
        return attributed.string
    }

    func boolValue(_ value: Any?) -> Bool {
        guard let raw = firstString(value)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return false
        }
        return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
    }

    func firstInt(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let string = firstString(value) {
            let cleaned = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
            if let int = Int(cleaned) {
                return int
            }
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let double = value as? Double {
            return Int(double)
        }
        if let float = value as? Float {
            return Int(float)
        }
        if let text = value as? String, let int = Int(text) {
            return int
        }
        return nil
    }

    func firstInt(_ value: Any?, key: String) -> Int? {
        guard let dict = value as? [String: Any] else { return nil }
        return firstInt(dict[key])
    }

    func imageURL(_ value: Any?) -> String? {
        if let text = firstString(value), !text.isEmpty, text != "true", text != "false" {
            return normalizedImageCandidate(text)
        }
        if let dict = value as? [String: Any] {
            if let text = firstString(dict["#text"]), !text.isEmpty {
                return normalizedImageCandidate(text)
            }
            let preferred = ["extralarge", "large", "medium", "small"]
            for size in preferred {
                if let candidate = normalizedImageCandidate(firstString(dict[size])), !candidate.isEmpty {
                    return candidate
                }
            }
        }
        guard let images = value as? [[String: Any]] else { return nil }
        let preferred = ["extralarge", "large", "medium", "small"]
        for size in preferred {
            if let match = images.first(where: { firstString($0["size"]) == size }),
               let text = normalizedImageCandidate(firstString(match["#text"])) {
                return text
            }
        }
        return images.compactMap { normalizedImageCandidate(firstString($0["#text"])) }.first
    }

    func normalizedImageCandidate(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Last.fm's common generic placeholder avatar/artwork.
        if trimmed.contains("2a96cbd8b46e442fc41c2b86b821562f") {
            return nil
        }
        return trimmed
    }

    func endpointCacheKey(params: [String: String]) -> String {
        params
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
    }

    func signature(for params: [String: String]) -> String {
        LastfmSignature.make(params: params, sharedSecret: config.sharedSecret)
    }

    var activeURLSession: URLSession {
        sessionProvider()
    }

    func formURLEncoded(_ params: [String: String]) -> String {
        params
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                "\(escape(key))=\(escape(value))"
            }
            .joined(separator: "&")
    }

    func escape(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    func cachedEntry(for key: String) -> EndpointCacheEntry? {
        endpointCacheLock.lock()
        defer { endpointCacheLock.unlock() }
        return endpointCache[key]
    }

    func setCachedEntry(_ entry: EndpointCacheEntry, for key: String) {
        endpointCacheLock.lock()
        endpointCache[key] = entry
        endpointCacheLock.unlock()
    }
}
