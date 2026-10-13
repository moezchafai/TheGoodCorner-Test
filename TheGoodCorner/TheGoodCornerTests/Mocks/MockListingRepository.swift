//
//  MockListingRepository.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 11/10/2026.


import Combine
import Foundation
@testable import TheGoodCorner

final class MockListingRepository: ListingRepository {

    // MARK: - Réponses préparées

    /// Réponse par défaut : une seule « page » qui contient tout.
    var listingsResult: Result<[Listing], Error> = .success([])

    /// Réponses propres à une recherche : `listingsByQuery["vélo"] = [...]`.
    var listingsByQuery: [String: [Listing]] = [:]

    /// Réponses pilotées à la main : permettent de simuler une requête lente
    /// (rien n'est émis tant que le test n'appelle pas `send`).
    var subjectsByQuery: [String: PassthroughSubject<[Listing], Error>] = [:]

    /// Pages numérotées à partir de 1, pour les tests de pagination.
    var pagesByNumber: [Int: Result<ListingsPage, Error>] = [:]

    /// Page lente pilotée à la main (même principe que `subjectsByQuery`).
    var subjectsByPage: [Int: PassthroughSubject<ListingsPage, Error>] = [:]

    var categoriesResult: Result<[ListingCategory], Error> = .success([])

    // MARK: - Appels enregistrés

    private(set) var fetchListingsCallCount = 0

    /// Textes de recherche reçus, dans l'ordre (`nil` = sans recherche).
    private(set) var receivedQueries: [String?] = []
    private(set) var receivedPages: [Int?] = []
    private(set) var receivedLimits: [Int?] = []

    func fetchListings(page: Int?, limit: Int?, query: String?) -> AnyPublisher<ListingsPage, Error> {
        fetchListingsCallCount += 1
        receivedQueries.append(query)
        receivedPages.append(page)
        receivedLimits.append(limit)

        // 1. Une recherche a ses propres réponses.
        if let query {
            if let subject = subjectsByQuery[query] {
                return subject.map(MockListingRepository.singlePage).eraseToAnyPublisher()
            }
            if let listings = listingsByQuery[query] {
                return Just(MockListingRepository.singlePage(listings))
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        }
        // 2. Sinon, une page numérotée.
        if let page {
            if let subject = subjectsByPage[page] {
                return subject.eraseToAnyPublisher()
            }
            if let result = pagesByNumber[page] {
                return result.publisher.eraseToAnyPublisher()
            }
        }
        // 3. Sinon, la réponse par défaut.
        return listingsResult
            .map(MockListingRepository.singlePage)
            .publisher
            .eraseToAnyPublisher()
    }

    func fetchCategories() -> AnyPublisher<[ListingCategory], Error> {
        categoriesResult.publisher.eraseToAnyPublisher()
    }

    private static func singlePage(_ listings: [Listing]) -> ListingsPage {
        ListingsPage(listings: listings, page: 1, total: listings.count, hasMore: false)
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
