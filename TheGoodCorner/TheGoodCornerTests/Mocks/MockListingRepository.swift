//
//  MockListingRepository.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import Combine
@testable import TheGoodCorner

final class MockListingRepository: ListingRepository {
    var listingsResult: Result<[Listing], Error> = .success([])
    // Résultats propres à une recherche : `listingsByQuery["vélo"] = [...]`.
    var listingsByQuery: [String: [Listing]] = [:]
    var categoriesResult: Result<[ListingCategory], Error> = .success([])

    private(set) var fetchListingsCallCount = 0
    private(set) var receivedQueries: [String?] = []

    func fetchListings(query: String?) -> AnyPublisher<[Listing], Error> {
        fetchListingsCallCount += 1
        receivedQueries.append(query)
        if let query, let listings = listingsByQuery[query] {
            return Just(listings).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        return listingsResult.publisher.eraseToAnyPublisher()
    }

    func fetchCategories() -> AnyPublisher<[ListingCategory], Error> {
        categoriesResult.publisher.eraseToAnyPublisher()
    }
}

extension Listing {
    static func stub(id: Int = 1, categoryID: Int = 1, isUrgent: Bool = false) -> Listing {
        Listing(id: id,
                title: "Annonce \(id)",
                description: "",
                price: 10,
                categoryID: categoryID,
                isUrgent: isUrgent,
                creationDate: Date(timeIntervalSince1970: 0),
                smallImageURL: nil,
                thumbImageURL: nil)
    }
}
