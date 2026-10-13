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

    /// Contenu qui n'est pas du JSON : simule une réponse illisible du serveur.
    private let malformedJSON = Data("pas du json".utf8)

    /// Crée un client API configuré avec le mock et l'URL de base de test.
    private func makeSUT(_ client: MockHTTPClient) -> ListingAPIClient {
        ListingAPIClient(httpClient: client, baseURL: baseURL)
    }

    // MARK: - Requête envoyée

    /// Vérifie que `fetchListings()` appelle bien `/listings` en GET, sans paramètre.
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

    /// Le texte de recherche doit arriver au serveur dans le paramètre `query`,
    /// et rien d'autre ne doit être ajouté à l'URL.
    func test_fetchListings_withQuery_sendsQueryParameter() throws {
        // Given
        let client = MockHTTPClient()
        client.result = .success(Data(Fixtures.listingsJSON.utf8))

        // When
        _ = syncResult(of: makeSUT(client).fetchListings(query: "vélo"))

        // Then
        let url = try XCTUnwrap(client.requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items, [URLQueryItem(name: "query", value: "vélo")])
    }
    /// La pagination envoie `page` puis `limit`, et rien d'autre quand il n'y a pas de recherche.
    func test_fetchListings_withPageAndLimit_sendsPaginationParameters() throws {
        // Given
        let client = MockHTTPClient()
        client.result = .success(Data(Fixtures.listingsJSON.utf8))

        // When
        _ = syncResult(of: makeSUT(client).fetchListings(page: 2, limit: 50, query: nil))

        // Then
        let url = try XCTUnwrap(client.requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items, [URLQueryItem(name: "page", value: "2"),
                               URLQueryItem(name: "limit", value: "50")])
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

    /// `GET /categories` renvoie un tableau simple, sans enveloppe.
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

    /// Le serveur répond, mais avec un contenu illisible : erreur de décodage.
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

    /// Une erreur du client HTTP doit être propagée telle quelle.
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
