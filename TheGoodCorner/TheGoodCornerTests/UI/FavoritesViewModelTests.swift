//
//  FavoritesViewModelTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
import XCTest
@testable import TheGoodCorner

/// Vérifie la logique des favoris, sans SwiftUI ni vrai stockage :
/// le `MockFavoritesRepository` joue le rôle du disque.
final class FavoritesViewModelTests: XCTestCase {

    private func makeSUT(stored: [Listing] = []) -> (sut: FavoritesViewModel, repo: MockFavoritesRepository) {
        let repo = MockFavoritesRepository(stored: stored)
        return (FavoritesViewModel(repository: repo), repo)
    }

    /// Au lancement, les favoris sauvegardés sont restaurés, dans le même ordre.
    func test_init_restoresSavedFavorites() {
        // Given
        let (sut, _) = makeSUT(stored: [.stub(id: 3), .stub(id: 1)])

        // Then
        XCTAssertEqual(sut.favorites.map(\.id), [3, 1])
        XCTAssertEqual(sut.count, 2)
    }

    /// Le dernier favori ajouté apparaît en premier dans « Mes favoris ».
    func test_toggle_addsMostRecentFavoriteFirst() {
        // Given
        let (sut, _) = makeSUT()

        // When
        sut.toggle(.stub(id: 1))
        sut.toggle(.stub(id: 2))

        // Then
        XCTAssertEqual(sut.favorites.map(\.id), [2, 1])
    }

    /// Toucher à nouveau le cœur retire l'annonce, sans toucher aux autres favoris.
    func test_toggle_twice_removesTheFavorite() {
        // Given
        let (sut, _) = makeSUT()
        sut.toggle(.stub(id: 1))
        sut.toggle(.stub(id: 2))

        // When
        sut.toggle(.stub(id: 1))

        // Then
        XCTAssertEqual(sut.favorites.map(\.id), [2])
        XCTAssertFalse(sut.isFavorite(.stub(id: 1)))
    }

    /// Chaque changement est sauvegardé tout de suite : un arrêt brutal de l'app ne perd rien.
    func test_toggle_savesAfterEveryChange() {
        // Given
        let (sut, repo) = makeSUT()

        // When / Then
        sut.toggle(.stub(id: 1))
        XCTAssertEqual(repo.stored.map(\.id), [1])

        sut.toggle(.stub(id: 2))
        XCTAssertEqual(repo.stored.map(\.id), [2, 1])

        sut.toggle(.stub(id: 2))
        XCTAssertEqual(repo.stored.map(\.id), [1])
        XCTAssertEqual(repo.saveCallCount, 3)
    }

    /// L'annonce stockée peut être une ancienne copie : seule l'identité (`id`) compte.
    /// Une version plus récente de la même annonce est donc reconnue comme favorite.
    func test_isFavorite_matchesByIdentifier() {
        // Given
        let (sut, _) = makeSUT()
        sut.toggle(.stub(id: 7, categoryID: 2))

        // Then : même id, autre contenu
        XCTAssertTrue(sut.isFavorite(.stub(id: 7, categoryID: 4)))
        XCTAssertFalse(sut.isFavorite(.stub(id: 8)))
    }

    /// Ajouter la même annonce deux fois ne crée pas de doublon : le second appel la retire.
    func test_toggle_sameIdTwice_neverDuplicates() {
        // Given
        let (sut, _) = makeSUT()

        // When
        sut.toggle(.stub(id: 5))
        sut.toggle(.stub(id: 5))
        sut.toggle(.stub(id: 5))

        // Then
        XCTAssertEqual(sut.favorites.map(\.id), [5])
    }

    /// Simule un redémarrage : un nouveau view model sur le même stockage retrouve les favoris.
    func test_favorites_surviveARelaunch() {
        // Given
        let (first, repo) = makeSUT()
        first.toggle(.stub(id: 1))
        first.toggle(.stub(id: 2))

        // When
        let second = FavoritesViewModel(repository: repo)

        // Then
        XCTAssertEqual(second.favorites.map(\.id), [2, 1])
    }
}
