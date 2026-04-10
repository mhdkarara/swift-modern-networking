import Foundation

// MARK: - API Errors
/// Defined as an enum to provide clear, actionable feedback to the UI layer.
enum HTTPError: Error {
    case invalidURL
    case requestFailed(Int)
    case decodingFailed
    case transport(Error)
    case unknown
}

// MARK: - API Request
/// A lightweight wrapper for constructing endpoint data.
struct APIRequest {
    var path: String
    var query: [URLQueryItem] = []
    var method: String = "GET"
}

// MARK: - API Client Protocol
/// Protocol-oriented design allows for "Mock" clients during Unit Testing.
protocol APIClientProtocol {
    func fetch<T: Decodable>(_ request: APIRequest, as type: T.Type) async throws -> T
}

// MARK: - API Client Implementation
struct APIClient: APIClientProtocol {
    
    let baseURL: URL
    let urlSession: URLSession
    let decoder: JSONDecoder
    
    /// Dependency Injection via Initializer
    /// This avoids hardcoding strings and allows for environment switching (Dev/Staging/Prod).
    init(
        baseURL: URL = URL(string: "https://jsonplaceholder.typicode.com")!,
        urlSession: URLSession = .shared,
        decoder: JSONDecoder = {
            let d = JSONDecoder()
            d.keyDecodingStrategy = .useDefaultKeys
            return d
        }()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.decoder = decoder
    }
    
    /// The core fetch function using Swift Concurrency (Async/Await)
    func fetch<T: Decodable>(_ request: APIRequest, as type: T.Type) async throws -> T {
        // 1. Construct URL
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false) else {
            throw HTTPError.invalidURL
        }
        
        if !request.query.isEmpty { 
            comps.queryItems = request.query 
        }
        
        guard let url = comps.url else { throw HTTPError.invalidURL }
        
        // 2. Prepare URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.timeoutInterval = 30
        
        // 3. Execute Network Call
        do {
            let (data, response) = try await urlSession.data(for: urlRequest)
            
            // Validate HTTP Response
            guard let http = response as? HTTPURLResponse else { 
                throw HTTPError.unknown 
            }
            
            guard (200..<300).contains(http.statusCode) else { 
                throw HTTPError.requestFailed(http.statusCode) 
            }
            
            // 4. Decode JSON to Model
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw HTTPError.decodingFailed
            }
            
        } catch {
            // Handle specialized error types
            if let err = error as? HTTPError { throw err }
            if let err = error as? URLError { throw HTTPError.transport(err) }
            throw HTTPError.unknown
        }
    }
}
