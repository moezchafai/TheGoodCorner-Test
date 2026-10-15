//
//  AppCoordinatorTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 15/10/2026.
//

import XCTest
@testable import TheGoodCorner

/// La navigation est une logique à part entière : on la teste sans SwiftUI.
@MainActor
final class AppCoordinatorTests: XCTestCase {

    private func makeSUT() -> AppCoordinator {
        AppCoordinator(categoryName: { _ in "Mode" })
    }

    /// Le bouton « Favoris » empile l'écran des favoris.
    func test_showFavorites_pushesFavoritesRoute() {
        let sut = makeSUT()

        sut.showFavorites()

        XCTAssertEqual(sut.path, [.favorites])
    }

    /// Un double toucher rapide ne doit pas empiler l'écran deux fois
    /// (sinon il faudrait appuyer deux fois sur « Retour »).
    func test_showFavorites_calledTwice_doesNotStackTheScreenTwice() {
        let sut = makeSUT()

        sut.showFavorites()
        sut.showFavorites()

        XCTAssertEqual(sut.path, [.favorites])
    }
}
