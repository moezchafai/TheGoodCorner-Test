//
//  ListingRepositoryTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 12/10/2026.

import XCTest
@testable import TheGoodCorner

/// Vérifie la traduction des DTOs en entités du Domain.
final class ListingRepositoryTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:8080")!

    private func makeSUT(returning json: String) -> ListingRepositoryImpl {
        let client = MockHTTPClient()
        client.result = .success(Data(json.utf8))
        let api = ListingAPIClient(httpClient: client, baseURL: baseURL)
        return ListingRepositoryImpl(api: api, baseURL: baseURL)
    }

    /// L'ordre de l'API est conservé. Les chemins d'images relatifs deviennent des URLs complètes,
    /// et une annonce dont `images_url` est vide (`{}`) n'a pas d'image, ce qui affichera un placeholder.
    func test_fetchListings_mapsToDomain_keepingOrder_andResolvingImages() throws {
        // Given
        let sut = makeSUT(returning: Fixtures.listingsJSON)

        // When
        let page = try syncResult(of: sut.fetchListings(page: 1, limit: 50, query: nil)).get()

        // Then
        XCTAssertEqual(page.listings.map(\.id), [1, 2])
        XCTAssertEqual(page.listings[0].categoryID, 7)
        XCTAssertEqual(page.listings[0].smallImageURL?.absoluteString,
                       "http://localhost:8080/images/ad-small/a.jpg")
        XCTAssertNil(page.listings[1].smallImageURL)
        XCTAssertNil(page.listings[1].thumbImageURL)
    }

    /// Le repository expose ce dont l'app a besoin pour demander la page suivante.
    func test_fetchListings_exposesPaginationMetadata() throws {
        // Given
        let sut = makeSUT(returning: #"{"page":2,"has_more":true,"total":300,"limit":50,"items":[]}"#)

        // When
        let page = try syncResult(of: sut.fetchListings(page: 2, limit: 50, query: nil)).get()

        // Then
        XCTAssertEqual(page, ListingsPage(listings: [], page: 2, total: 300, hasMore: true))
    }
}
