//
//  EndpointTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 12/10/2026.
//

import XCTest
@testable import TheGoodCorner

/// Vérifie la construction des URLs d'API.
final class EndpointTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:8080")!

    /// Les paramètres sont envoyés dans l'ordre (`page`, `limit`, `query`), et le caractère accentué
    /// est encodé : le serveur ne répond pas à un `é` brut, mais accepte `%C3%A9`.
    func test_listings_withPaginationAndAccentedQuery_buildsEncodedURLInOrder() throws {
        // When
        let url = try XCTUnwrap(Endpoint.listings(page: 2, limit: 20, query: "vélo").url(baseURL: baseURL))

        // Then
        XCTAssertEqual(url.absoluteString,
                       "http://localhost:8080/listings?page=2&limit=20&query=v%C3%A9lo")
    }
}
