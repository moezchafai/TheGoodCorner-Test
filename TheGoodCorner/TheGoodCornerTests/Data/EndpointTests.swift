//
//  EndpointTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 12/10/2026.
//

import XCTest
@testable import TheGoodCorner


final class EndpointTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:8080")!

    // Récupère les paramètres d'une URL pour vérifier leurs noms et valeurs.
    private func queryItems(of url: URL) -> [URLQueryItem]? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    }

    // MARK: - Endpoints utilisés par l'app

    // Sans paramètre : l'URL doit être exactement `/listings`, sans `?` parasite.
    func test_listings_withoutParameters_buildsCorrectURL() throws {
        let url = try XCTUnwrap(Endpoint.listings().url(baseURL: baseURL))

        XCTAssertEqual(url.absoluteString, "http://localhost:8080/listings")
        XCTAssertNil(queryItems(of: url))
    }

    func test_categories_buildsCorrectURL() throws {
        let url = try XCTUnwrap(Endpoint.categories.url(baseURL: baseURL))

        XCTAssertEqual(url.absoluteString, "http://localhost:8080/categories")
        XCTAssertNil(queryItems(of: url))
    }

    // MARK: - Paramètres optionnels (prévus pour un éventuel bonus pagination ou recherche)

    // Avec pagination et recherche : les 3 paramètres doivent être présents dans l'ordre.
    func test_listings_withPaginationAndQuery_buildsQueryItemsInOrder() throws {
        let url = try XCTUnwrap(
            Endpoint.listings(page: 2, limit: 20, query: "vélo").url(baseURL: baseURL)
        )
        let items = queryItems(of: url)

        XCTAssertEqual(items?.map(\.name), ["page", "limit", "query"])
        XCTAssertEqual(items?.map(\.value), ["2", "20", "vélo"])
    }

    // Seuls les paramètres fournis sont envoyés : pas de `query=` si aucune recherche.
    func test_listings_withPaginationOnly_omitsQuery() throws {
        let url = try XCTUnwrap(Endpoint.listings(page: 1, limit: 50).url(baseURL: baseURL))
        let items = queryItems(of: url)

        XCTAssertEqual(items?.map(\.name), ["page", "limit"])
        XCTAssertEqual(items?.map(\.value), ["1", "50"])
    }

    // Une recherche vide (champ effacé par l'utilisateur) ne doit pas ajouter `?query=`.
    func test_listings_withEmptyQuery_ignoresQueryItem() throws {
        let url = try XCTUnwrap(Endpoint.listings(query: "").url(baseURL: baseURL))

        XCTAssertNil(queryItems(of: url))
    }
}
