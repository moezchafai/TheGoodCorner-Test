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

    init(api: ListingAPI, baseURL: URL) {
        self.api = api
        self.baseURL = baseURL
    }

    func fetchListings(page: Int?, limit: Int?, query: String?) -> AnyPublisher<ListingsPage, Error> {
        api.fetchListings(page: page, limit: limit, query: query)
            .map { [baseURL] response in
                ListingsPage(listings: response.items.map { $0.toDomain(baseURL: baseURL) },
                             page: response.page,
                             total: response.total,
                             hasMore: response.hasMore)
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
