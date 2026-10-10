//
//  HTTPClient.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//


import Foundation
import Combine

protocol HTTPClient {
    func send(_ request: URLRequest) -> AnyPublisher<Data, NetworkError>
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) -> AnyPublisher<Data, NetworkError> {
        session.dataTaskPublisher(for: request)
            .tryMap { output -> Data in
                guard let http = output.response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw NetworkError.badStatus(http.statusCode)
                }
                return output.data
            }
            .mapError { error -> NetworkError in
                (error as? NetworkError) ?? .transport
            }
            .eraseToAnyPublisher()
    }
}
