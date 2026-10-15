//
//  UserDefaultsFavoritesStoreTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 13/10/2026.
//

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

    /// Les favoris survivent à un redémarrage : une nouvelle instance du store, sur les mêmes
    /// réglages, retrouve les annonces à l'identique et dans le même ordre.
    func test_favorites_persistAcrossStoreInstances() {
        // Given
        let favorites = [Listing.stub(id: 3), Listing.stub(id: 1)]
        UserDefaultsFavoritesStore(defaults: defaults).saveFavorites(favorites)

        // When : nouvelle instance, comme après un redémarrage
        let reloaded = UserDefaultsFavoritesStore(defaults: defaults).loadFavorites()

        // Then
        XCTAssertEqual(reloaded, favorites)
    }

    /// Des données illisibles ne doivent pas faire planter l'app au lancement.
    func test_loadFavorites_withCorruptedData_returnsEmptyList() {
        // Given
        defaults.set(Data("pas du json".utf8), forKey: "favorites.listings.v1")

        // Then
        XCTAssertTrue(UserDefaultsFavoritesStore(defaults: defaults).loadFavorites().isEmpty)
    }
}
