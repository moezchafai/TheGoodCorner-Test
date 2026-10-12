//
//  ListingRepositoryImpl.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//


import Foundation
import Combine

final class ListingRepositoryImpl: ListingRepository {

    private let api: ListingAPI
    private let baseURL: URL

    init(api: ListingAPI,
         baseURL: URL = URL(string: "http://localhost:8080")!) {
        self.api = api
        self.baseURL = baseURL
    }

    func fetchListings(query: String?) -> AnyPublisher<[Listing], Error> {
        api.fetchListings(query: query)
            .map { [baseURL] response in
                response.items.map { $0.toDomain(baseURL: baseURL) }
            }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    func fetchCategories() -> AnyPublisher<[ListingCategory], Error> {
        api.fetchCategories()
            .map { $0.map { $0.toDomain() } }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}
