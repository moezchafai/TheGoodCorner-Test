//
//  MockListingRepository.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 11/10/2026.
//

import Combine
import Foundation
@testable import TheGoodCorner

final class MockListingRepository: ListingRepository {

    /// Réponse par défaut, pour toute requête sans réponse dédiée.
    var listingsResult: Result<[Listing], Error> = .success([])

    /// Réponses propres à une recherche : `listingsByQuery["vélo"] = [...]`.
    var listingsByQuery: [String: [Listing]] = [:]

    /// Réponses pilotées à la main : permettent de simuler une requête lente
    /// (rien n'est émis tant que le test n'appelle pas `send`).
    var subjectsByQuery: [String: PassthroughSubject<[Listing], Error>] = [:]

    var categoriesResult: Result<[ListingCategory], Error> = .success([])

    private(set) var fetchListingsCallCount = 0

    /// Textes de recherche reçus, dans l'ordre (`nil` = chargement sans recherche).
    private(set) var receivedQueries: [String?] = []

    func fetchListings(query: String?) -> AnyPublisher<[Listing], Error> {
        fetchListingsCallCount += 1
        receivedQueries.append(query)

        if let query, let subject = subjectsByQuery[query] {
            return subject.eraseToAnyPublisher()
        }
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
