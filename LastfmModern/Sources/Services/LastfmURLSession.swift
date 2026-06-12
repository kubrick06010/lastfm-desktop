import Foundation
import CFNetwork

extension URLSession {
    static func lastfmSession(proxySettings: ProxySettings) -> URLSession {
        switch proxySettings.mode {
        case .system:
            return .shared
        case .none:
            let configuration = URLSessionConfiguration.ephemeral
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: 0,
                kCFNetworkProxiesHTTPSEnable as String: 0,
                kCFNetworkProxiesSOCKSEnable as String: 0
            ]
            return URLSession(configuration: configuration)
        case .http, .socks5:
            guard proxySettings.hasRequiredEndpoint,
                  let port = proxySettings.normalizedPort else {
                return .shared
            }
            let configuration = URLSessionConfiguration.ephemeral
            var proxy: [AnyHashable: Any] = [
                kCFNetworkProxiesHTTPEnable as String: 0,
                kCFNetworkProxiesHTTPSEnable as String: 0,
                kCFNetworkProxiesSOCKSEnable as String: 0
            ]
            switch proxySettings.mode {
            case .http:
                proxy[kCFNetworkProxiesHTTPEnable as String] = 1
                proxy[kCFNetworkProxiesHTTPSEnable as String] = 1
                proxy[kCFNetworkProxiesHTTPProxy as String] = proxySettings.normalizedHost
                proxy[kCFNetworkProxiesHTTPSProxy as String] = proxySettings.normalizedHost
                proxy[kCFNetworkProxiesHTTPPort as String] = port
                proxy[kCFNetworkProxiesHTTPSPort as String] = port
            case .socks5:
                proxy[kCFNetworkProxiesSOCKSEnable as String] = 1
                proxy[kCFNetworkProxiesSOCKSProxy as String] = proxySettings.normalizedHost
                proxy[kCFNetworkProxiesSOCKSPort as String] = port
            default:
                break
            }
            if let username = proxySettings.normalizedUsername {
                proxy[kCFProxyUsernameKey as String] = username
            }
            if let password = proxySettings.normalizedPassword {
                proxy[kCFProxyPasswordKey as String] = password
            }
            configuration.connectionProxyDictionary = proxy
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            return URLSession(configuration: configuration)
        }
    }
}
