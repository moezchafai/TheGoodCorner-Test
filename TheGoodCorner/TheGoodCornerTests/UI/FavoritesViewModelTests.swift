//
//  FavoritesViewModelTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 13/10/2026.
//

import XCTest
@testable import TheGoodCorner

/// Vérifie la logique des favoris, sans SwiftUI ni vrai stockage :
/// le `MockFavoritesRepository` joue le rôle du disque.
final class FavoritesViewModelTests: XCTestCase {

    /// Le dernier favori ajouté apparaît en premier ; toucher à nouveau le cœur retire l'annonce.
    func test_toggle_addsMostRecentFirst_andSecondToggleRemoves() {
        // Given
        let sut = FavoritesViewModel(repository: MockFavoritesRepository())

        // When / Then : ajout
        sut.toggle(.stub(id: 1))
        sut.toggle(.stub(id: 2))
        XCTAssertEqual(sut.favorites.map(\.id), [2, 1])

        // When / Then : retrait
        sut.toggle(.stub(id: 1))
        XCTAssertEqual(sut.favorites.map(\.id), [2])
        XCTAssertFalse(sut.isFavorite(.stub(id: 1)))
    }

    /// Un nouveau view model sur le même stockage retrouve les favoris : prouve à la fois
    /// que chaque changement est sauvegardé et que le lancement les restaure.
    func test_favorites_surviveARelaunch() {
        // Given
        let repo = MockFavoritesRepository()
        let first = FavoritesViewModel(repository: repo)
        first.toggle(.stub(id: 1))
        first.toggle(.stub(id: 2))

        // When
        let second = FavoritesViewModel(repository: repo)

        // Then
        XCTAssertEqual(second.favorites.map(\.id), [2, 1])
    }
}
