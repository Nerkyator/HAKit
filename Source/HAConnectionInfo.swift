import Foundation

/// Information for connecting to the server
public struct HAConnectionInfo: Equatable {
    /// Thrown if connection info was not able to be created
    enum CreationError: Error {
        /// The URL's host was empty, which would otherwise crash if used
        case emptyHostname
        /// The port provided exceeds the maximum allowed TCP port (2^16-1)
        case invalidPort
    }
    
    /// Certificate validation handler
    public typealias EvaluateCertificate = (SecTrust, (Result<Void, Error>) -> Void) -> Void
    
    /// Create a connection info
    ///
    /// URLs are in the form of: https://url-to-hass:8123 and /api/websocket will be appended.
    ///
    /// - Parameter url: The url to connect to
    /// - Parameter userAgent: Optionally change the User-Agent to this
    /// - Parameter evaluateCertificate: Optionally override default SecTrust validation
    /// - Throws: If the URL provided is invalid in some way, see `CreationError`
    public init(url: URL, userAgent: String? = nil, evaluateCertificate: EvaluateCertificate? = nil) throws {
        guard let host = url.host, !host.isEmpty else {
            throw CreationError.emptyHostname
        }
        
        guard (url.port ?? 80) <= UInt16.max else {
            throw CreationError.invalidPort
        }
        
        self.url = Self.sanitize(url)
        self.userAgent = userAgent
        self.evaluateCertificate = evaluateCertificate
    }
    
    /// The base URL for the WebSocket connection
    public var url: URL
    
    /// The full websocket URL
    public var webSocketURL: URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme else {
            return URL(string: "")!
        }
        
        if scheme == "https" || scheme == "wss" {
            components.scheme = "wss"
        } else {
            components.scheme = "ws"
        }
        
        guard var newUrl = components.url else {
            return URL(string: "")!
        }
        
        newUrl.appendPathComponent("api/websocket")
        return newUrl
    }
    
    /// The user agent to use in the connection
    public var userAgent: String?
    
    /// Used to validate certificate, if provided
    /// TODO: 🟡  Implement custom validation
    internal var evaluateCertificate: EvaluateCertificate?
    
    /// Should this connection info take over an existing connection?
    ///
    /// - Parameter webSocket: The WebSocket to test
    /// - Returns: true if the connection should be replaced, false otherwise
    internal func shouldReplace(_ webSocket: SocketStream) -> Bool {
        Self.sanitize(webSocket.url) != Self.sanitize(url)
    }
    
    internal func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        if let host = url.host {
            if let port = url.port, port != 80, port != 443 {
                // URLSession behavior: omit optional port if 80 or 443
                // Starscream does the opposite, where it always includes port
                request.setValue("\(host):\(port)", forHTTPHeaderField: "Host")
            } else {
                request.setValue(host, forHTTPHeaderField: "Host")
            }
        }
        
        return request
    }
    
    /// Create a URLRequest for a given REST API path and query items
    /// - Parameters:
    ///   - path: The path to invoke, including the 'api/' part.
    ///   - queryItems: The query items to include in the URL
    /// - Returns: The URLRequest for the given parameters
    internal func request(
        path: String,
        queryItems: [URLQueryItem]
    ) -> URLRequest {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        urlComponents.path += "/" + path
        
        if !queryItems.isEmpty {
            // providing an empty array will cause `?` to be added in all cases
            urlComponents.queryItems = (urlComponents.queryItems ?? []) + queryItems
        }
        
        return request(url: urlComponents.url!)
    }
    
    /// Create a new WebSocket connection
    /// - Returns: The newly-created SocketStream connection
    internal func webSocket() -> SocketStream {
        let webSocket: SocketStream = SocketStream(withURL: webSocketURL)
        return webSocket
    }
    
    /// Clean up the given URL
    /// - Parameter url: The raw URL
    /// - Returns: A URL with common issues removed
    private static func sanitize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              var path = components.percentEncodedPath.removingPercentEncoding else {
            return url
        }
        
        let substringsToRemove = [
            "/api/websocket",
            "/api",
        ]
        
        for substring in substringsToRemove {
            path = path.replacingOccurrences(of: substring, with: "")
        }
        
        while path.hasSuffix("/") {
            path.removeLast()
        }
        
        components.percentEncodedPath = path
        
        return components.url!
    }
    
    public static func == (lhs: HAConnectionInfo, rhs: HAConnectionInfo) -> Bool {
        lhs.url == rhs.url
    }
}
