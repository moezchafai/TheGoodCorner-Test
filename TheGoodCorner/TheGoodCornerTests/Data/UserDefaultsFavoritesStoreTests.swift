//
//  UserDefaultsFavoritesStoreTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
import XCTest
@testable import TheGoodCorner

/// Vérifie la persistance des favoris, sur une suite `UserDefaults` jetable
/// (les vrais réglages de l'app ne sont jamais touchés).
final class UserDefaultsFavoritesStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "tests.favorites.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeSUT() -> UserDefaultsFavoritesStore {
        UserDefaultsFavoritesStore(defaults: defaults)
    }

    /// Une annonce avec tous ses champs renseignés, pour vérifier qu'aucun n'est perdu.
    private let fullListing = Listing(
        id: 42,
        title: "Vinyle",
        description: "Bon état",
        price: 10,
        categoryID: 7,
        isUrgent: true,
        creationDate: Date(timeIntervalSince1970: 1_573_039_355),
        smallImageURL: URL(string: "http://localhost:8080/images/ad-small/a.jpg"),
        thumbImageURL: URL(string: "http://localhost:8080/images/ad-thumb/a.jpg")
    )

    /// Au premier lancement, il n'y a pas de favori.
    func test_loadFavorites_whenNothingSaved_returnsEmptyList() {
        XCTAssertTrue(makeSUT().loadFavorites().isEmpty)
    }

    /// Sauvegarder puis relire restitue les annonces à l'identique, dans le même ordre.
    func test_saveThenLoad_roundTripsListingsInOrder() {
        // Given
        let sut = makeSUT()
        let favorites = [Listing.stub(id: 3), fullListing, Listing.stub(id: 1)]

        // When
        sut.saveFavorites(favorites)

        // Then
        XCTAssertEqual(sut.loadFavorites(), favorites)
    }

    /// Les favoris survivent à un « relancement » de l'app : une nouvelle instance
    /// du store, sur les mêmes réglages, retrouve ce qui a été sauvegardé.
    func test_favorites_persistAcrossStoreInstances() {
        // Given
        makeSUT().saveFavorites([fullListing])

        // When : nouvelle instance, comme après un redémarrage
        let reloaded = makeSUT().loadFavorites()

        // Then
        XCTAssertEqual(reloaded, [fullListing])
    }

    /// Des données illisibles ne doivent pas faire planter l'app au lancement.
    func test_loadFavorites_withCorruptedData_returnsEmptyList() {
        // Given
        defaults.set(Data("pas du json".utf8), forKey: "favorites.listings.v1")

        // Then
        XCTAssertTrue(makeSUT().loadFavorites().isEmpty)
    }

    /// Sauvegarder une liste vide efface les favoris (le dernier cœur retiré).
    func test_saveFavorites_withEmptyList_clearsFavorites() {
        // Given
        let sut = makeSUT()
        sut.saveFavorites([fullListing])

        // When
        sut.saveFavorites([])

        // Then
        XCTAssertTrue(sut.loadFavorites().isEmpty)
    }
}
