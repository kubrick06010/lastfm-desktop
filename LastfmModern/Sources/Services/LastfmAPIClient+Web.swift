import Foundation

extension LastfmAPIClient {
    func fetchPublicHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("LastfmModern/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await activeURLSession.data(for: request)
            guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
                throw LastfmAPIError.invalidResponse
            }
            return html
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                    throw LastfmAPIError.networkUnavailable
                default:
                    throw LastfmAPIError.transport
                }
            }
            throw LastfmAPIError.transport
        }
    }
}
