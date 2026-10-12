//
//  ListingRepositoryTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 12/10/2026.
//

import Foundation
import XCTest
@testable import TheGoodCorner

/// Vérifie le mapping DTO → Domain fait par le repository.
/// Le `MockHTTPClient` renvoie des données préparées, sans aucun appel réseau.
final class ListingRepositoryTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:8080")!

    // Crée un repository complet (API + repository) branché sur le mock.
    private func makeSUT(_ client: MockHTTPClient) -> ListingRepositoryImpl {
        let api = ListingAPIClient(httpClient: client, baseURL: baseURL)
        return ListingRepositoryImpl(api: api, baseURL: baseURL)
    }

    // Raccourci : un mock qui renvoie toujours le même JSON d'annonces.
    private func clientReturningListings() -> MockHTTPClient {
        let client = MockHTTPClient()
        client.result = .success(Data(Fixtures.listingsJSON.utf8))
        return client
    }

    // MARK: - Mapping DTO → Domain

    // Vérifie que l'ordre renvoyé par l'API est préservé dans le Domain.
    func test_fetchListings_mapsToDomain_keepingAPIOrder() throws {
        let sut = makeSUT(clientReturningListings())

        let listings = try syncResult(of: sut.fetchListings()).get()

        XCTAssertEqual(listings.map(\.id), [1, 2])
        XCTAssertEqual(listings[0].title, "Vinyle")
        XCTAssertEqual(listings[0].categoryID, 7)
        XCTAssertTrue(listings[0].isUrgent)
        XCTAssertFalse(listings[1].isUrgent)
    }

    // Vérifie que les URLs d'images relatives (`/images/...`) sont bien préfixées
    /// par le base URL, et que les annonces sans image retournent `nil`.
    func test_fetchListings_resolvesRelativeImagePaths_andHandlesMissingImages() throws {
        let sut = makeSUT(clientReturningListings())

        let listings = try syncResult(of: sut.fetchListings()).get()

        XCTAssertEqual(listings[0].smallImageURL?.absoluteString,
                       "http://localhost:8080/images/ad-small/a.jpg")
        XCTAssertEqual(listings[0].thumbImageURL?.absoluteString,
                       "http://localhost:8080/images/ad-thumb/a.jpg")
        XCTAssertNil(listings[1].smallImageURL)
        XCTAssertNil(listings[1].thumbImageURL)
    }

    // Quand `description` est absente du JSON, le Domain utilise une chaîne vide plutôt qu'une valeur `nil`.
    func test_fetchListings_whenDescriptionIsMissing_usesEmptyString() throws {
        let sut = makeSUT(clientReturningListings())

        let listings = try syncResult(of: sut.fetchListings()).get()

        XCTAssertEqual(listings[0].description, "Bon état")
        XCTAssertEqual(listings[1].description, "")
    }

    // MARK: - Catégories

    func test_fetchCategories_mapsToDomain() throws {
        let client = MockHTTPClient()
        client.result = .success(Data(Fixtures.categoriesJSON.utf8))

        let categories = try syncResult(of: makeSUT(client).fetchCategories()).get()

        XCTAssertEqual(categories, [ListingCategory(id: 1, name: "Véhicule"),
                                    ListingCategory(id: 2, name: "Mode")])
    }

    // MARK: - Erreurs

    // Une erreur réseau (ex : pas de connexion) doit être remontée telle quelle.
    func test_fetchListings_whenNetworkFails_exposesTheUnderlyingError() {
        let client = MockHTTPClient()
        client.result = .failure(.transport)

        let result = syncResult(of: makeSUT(client).fetchListings())

        guard case .failure(let error) = result else { return XCTFail("Une erreur était attendue") }
        XCTAssertEqual(error as? NetworkError, .transport)
    }
}
