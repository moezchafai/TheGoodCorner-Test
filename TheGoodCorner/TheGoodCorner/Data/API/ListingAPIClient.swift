//
//  ListingAPIClient.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//


import Foundation
import Combine

protocol ListingAPI {
    func fetchListings(query: String?) -> AnyPublisher<ListingsResponseDTO, NetworkError>
    func fetchCategories() -> AnyPublisher<[CategoryDTO], NetworkError>
}

extension ListingAPI {
    func fetchListings() -> AnyPublisher<ListingsResponseDTO, NetworkError> {
        fetchListings(query: nil)
    }
}

final class ListingAPIClient: ListingAPI {

    private let httpClient: HTTPClient
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(httpClient: HTTPClient,
         baseURL: URL = URL(string: "http://localhost:8080")!) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.decoder = Self.makeDecoder()
    }

    // MARK: - ListingAPI

    func fetchListings(query: String?) -> AnyPublisher<ListingsResponseDTO, NetworkError> {
        request(.listings(query: query))
    }

    func fetchCategories() -> AnyPublisher<[CategoryDTO], NetworkError> {
        request(.categories)
    }

    // MARK: - Private

    private func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, NetworkError> {
        guard let url = endpoint.url(baseURL: baseURL) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }

        return httpClient.send(URLRequest(url: url))
            .decode(type: T.self, decoder: decoder)
            .mapError { error -> NetworkError in
                (error as? NetworkError) ?? .decodingFailed
            }
            .eraseToAnyPublisher()
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
