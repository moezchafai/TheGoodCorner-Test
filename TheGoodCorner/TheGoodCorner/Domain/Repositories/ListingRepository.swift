//
//  ListingRepository.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation
import Combine

protocol ListingRepository {
    /// `page` et `limit` à nil : le serveur renvoie tout le catalogue d'un coup.
    func fetchListings(page: Int?, limit: Int?, query: String?) -> AnyPublisher<ListingsPage, Error>
    func fetchCategories() -> AnyPublisher<[ListingCategory], Error>
}

extension ListingRepository {
    func fetchListings(query: String?) -> AnyPublisher<[Listing], Error> {
        fetchListings(page: nil, limit: nil, query: query)
            .map(\.listings)
            .eraseToAnyPublisher()
    }

    func fetchListings() -> AnyPublisher<[Listing], Error> {
        fetchListings(query: nil)
    }
}
