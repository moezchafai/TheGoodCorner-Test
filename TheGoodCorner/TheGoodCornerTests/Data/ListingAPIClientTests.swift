//
//
//  ListingAPIClientTests.swift
//  TheGoodCornerTests
//


import XCTest
@testable import TheGoodCorner

/// Vérifie `ListingAPIClient` sans réseau : le `MockHTTPClient` renvoie des données préparées
/// et enregistre les requêtes envoyées.
final class ListingAPIClientTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:8080")!

    private func makeSUT(_ client: MockHTTPClient) -> ListingAPIClient {
        ListingAPIClient(httpClient: client, baseURL: baseURL)
    }

    /// Sans paramètre, l'app demande `/listings` en GET (tout le catalogue : le filtre local en a besoin).
    /// Le JSON est en snake_case (`category_id`, `has_more`, `is_urgent`) : le décodeur le convertit.
    func test_fetchListings_sendsGETToListings_andDecodesEnvelope() throws {
        // Given
        let client = MockHTTPClient()
        client.result = .success(Data(Fixtures.listingsJSON.utf8))

        // When
        let response = try syncResult(of: makeSUT(client).fetchListings()).get()

        // Then
        XCTAssertEqual(client.requests.first?.url?.absoluteString, "http://localhost:8080/listings")
        XCTAssertEqual(client.requests.first?.httpMethod, "GET")
        XCTAssertEqual(response.total, 2)
        XCTAssertFalse(response.hasMore)
        XCTAssertEqual(response.items.map(\.id), [1, 2])
        XCTAssertEqual(response.items[0].categoryId, 7)
        XCTAssertTrue(response.items[0].isUrgent)
    }

    /// Le serveur répond, mais avec un contenu illisible : erreur de décodage.
    func test_fetchListings_withInvalidJSON_failsWithDecodingFailed() {
        // Given
        let client = MockHTTPClient()
        client.result = .success(Data("pas du json".utf8))

        // When
        let result = syncResult(of: makeSUT(client).fetchListings())

        // Then
        guard case .failure(let error) = result else { return XCTFail("Une erreur était attendue") }
        XCTAssertEqual(error, .decodingFailed)
    }

    /// Une erreur du client HTTP est propagée telle quelle. Sans ce test, une panne serveur
    /// pourrait être confondue avec une erreur de décodage.
    func test_fetchListings_whenServerFails_propagatesBadStatus() {
        // Given
        let client = MockHTTPClient()
        client.result = .failure(.badStatus(500))

        // When
        let result = syncResult(of: makeSUT(client).fetchListings())

        // Then
        guard case .failure(let error) = result else { return XCTFail("Une erreur était attendue") }
        XCTAssertEqual(error, .badStatus(500))
    }
}
