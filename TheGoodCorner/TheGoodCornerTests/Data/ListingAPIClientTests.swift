//
//
//  ListingAPIClientTests.swift
//  TheGoodCornerTests
//

import Foundation
import XCTest
@testable import TheGoodCorner

/// Vérifie le comportement de `ListingAPIClient` sans réseau.
/// Le `MockHTTPClient` renvoie des données préparées et enregistre les requêtes envoyées.

final class ListingAPIClientTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:8080")!

    // Contenu qui n'est pas du JSON : simule une réponse illisible du serveur.
    private let malformedJSON = Data("pas du json".utf8)

    // Crée un client API configuré avec le mock et le base URL de test.
    private func makeSUT(_ client: MockHTTPClient) -> ListingAPIClient {
        ListingAPIClient(httpClient: client, baseURL: baseURL)
    }

    // MARK: - Requête envoyée

    // Vérifie que `fetchListings()` appelle bien `/listings` en GET.
    func test_fetchListings_sendsGETRequestToListingsEndpoint() {
        // Given
        let client = MockHTTPClient()
        client.result = .success(Data(Fixtures.listingsJSON.utf8))

        // When
        _ = syncResult(of: makeSUT(client).fetchListings())

        // Then
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests.first?.url?.absoluteString, "http://localhost:8080/listings")
        XCTAssertEqual(client.requests.first?.httpMethod, "GET")
    }

    // MARK: - Décodage

    /// Le JSON est en snake_case (`category_id`, `has_more`, `is_urgent`).
    /// Ce test prouve que le décodeur convertit bien vers les propriétés Swift.
    func test_fetchListings_decodesEnvelopeAndItems() throws {
        // Given
        let client = MockHTTPClient()
        client.result = .success(Data(Fixtures.listingsJSON.utf8))

        // When
        let response = try syncResult(of: makeSUT(client).fetchListings()).get()

        // Then
        XCTAssertEqual(response.total, 2)
        XCTAssertFalse(response.hasMore)
        XCTAssertEqual(response.items.map(\.id), [1, 2])
        XCTAssertEqual(response.items[0].categoryId, 7)
        XCTAssertTrue(response.items[0].isUrgent)
    }

    // `GET /categories` renvoie un tableau simple, sans enveloppe.
    /// On vérifie aussi que le bon endpoint est appelé.
    func test_fetchCategories_decodesCategories() throws {
        // Given
        let client = MockHTTPClient()
        client.result = .success(Data(Fixtures.categoriesJSON.utf8))

        // When
        let categories = try syncResult(of: makeSUT(client).fetchCategories()).get()

        // Then
        XCTAssertEqual(categories.map(\.name), ["Véhicule", "Mode"])
        XCTAssertEqual(client.requests.first?.url?.absoluteString, "http://localhost:8080/categories")
    }

    // MARK: - Erreurs

    // Le serveur répond, mais avec un contenu illisible → erreur de décodage.
    func test_fetchListings_withInvalidJSON_failsWithDecodingFailed() {
        // Given
        let client = MockHTTPClient()
        client.result = .success(malformedJSON)

        // When
        let result = syncResult(of: makeSUT(client).fetchListings())

        // Then
        guard case .failure(let error) = result else { return XCTFail("Une erreur était attendue") }
        XCTAssertEqual(error, .decodingFailed)
    }

    // Une erreur du client HTTP doit être propagée telle quelle.
    /// Sans ce test, une panne serveur pourrait être confondue avec une erreur de décodage.
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
