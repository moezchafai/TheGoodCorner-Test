//
//  ListingListViewModelTests.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 12/10/2026.
//

import Foundation
import XCTest
import Combine
@testable import TheGoodCorner

/// Vérifie le comportement du `ListingListViewModel` sans réseau.
/// Le `MockListingRepository` renvoie des données préparées pour tester :
/// - les transitions d'état (loading → loaded / error / empty),
/// - le filtre par catégorie,
/// - la préservation de l'ordre renvoyé par l'API.
final class ListingListViewModelTests: XCTestCase {

    private struct TestError: Error {}

    private var cancellables = Set<AnyCancellable>()

    private let mode = ListingCategory(id: 2, name: "Mode")
    private let maison = ListingCategory(id: 4, name: "Maison")

    // MARK: - Aides

    /// Crée un ViewModel avec un repository mock configuré.
    private func makeSUT(listings: [Listing]) -> (sut: ListingListViewModel, repo: MockListingRepository) {
        let repo = MockListingRepository()
        repo.listingsResult = .success(listings)
        repo.categoriesResult = .success([mode, maison])
        return (ListingListViewModel(repository: repo), repo)
    }

    /// Attend que le ViewModel quitte l'état `.loading` avant de vérifier quoi que ce soit.
    /// Nécessaire car le chargement est asynchrone (receive(on: main)).
    private func waitForLoadToFinish(_ sut: ListingListViewModel) {
        let exp = expectation(description: "le chargement est terminé")
        sut.$state
            .first { $0 != .loading }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        wait(for: [exp], timeout: 1)
    }

    // MARK: - Chargement

    /// L'API renvoie déjà les annonces triées (urgentes d'abord) :
    /// l'app ne doit pas les retrier. Les IDs (3, 1, 2) le prouvent.
    func test_load_success_keepsAPIOrder() {
        // Given
        let (sut, _) = makeSUT(listings: [.stub(id: 3), .stub(id: 1), .stub(id: 2)])

        // When
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.visibleListings.map(\.id), [3, 1, 2])
    }

    /// `loadIfNeeded()` est appelé à chaque apparition de l'écran.
    /// Il ne doit déclencher qu'un seul appel réseau, pas un par apparition.
    func test_loadIfNeeded_loadsOnlyOnce() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])

        // When
        sut.loadIfNeeded()
        waitForLoadToFinish(sut)
        sut.loadIfNeeded()

        // Then
        XCTAssertEqual(repo.fetchListingsCallCount, 1)
    }

    // MARK: - Filtre par catégorie

    /// L'API n'a pas de paramètre de catégorie : le filtre se fait dans l'app.
    /// Choisir une catégorie garde ses annonces dans l'ordre d'origine ;
    /// « Toutes » (`nil`) restaure la liste complète.
    func test_selectingCategory_filtersListings_andNilRestoresAll() {
        // Given
        let (sut, _) = makeSUT(listings: [.stub(id: 1, categoryID: 2),
                                          .stub(id: 2, categoryID: 4),
                                          .stub(id: 3, categoryID: 2)])
        sut.load()
        waitForLoadToFinish(sut)

        // When / Then : filtre actif
        sut.selectedCategory = mode
        XCTAssertEqual(sut.visibleListings.map(\.id), [1, 3])

        // When / Then : retour à « Toutes »
        sut.selectedCategory = nil
        XCTAssertEqual(sut.visibleListings.map(\.id), [1, 2, 3])
    }

    /// Une catégorie sans annonce n'est pas une erreur :
    /// l'état reste `.loaded` et la liste est vide.
    /// Cela permet à l'écran d'afficher un état vide intentionnel.
    func test_categoryWithoutListings_givesEmptyVisibleList() {
        // Given
        let (sut, _) = makeSUT(listings: [.stub(id: 1, categoryID: 2)])
        sut.load()
        waitForLoadToFinish(sut)

        // When
        sut.selectedCategory = maison

        // Then
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertTrue(sut.visibleListings.isEmpty)
    }

    /// Une annonce dont la catégorie n'est pas dans `/categories`
    /// ne doit pas faire planter l'écran : on affiche un nom par défaut.
    func test_categoryName_fallsBackToAutre_forUnknownCategory() {
        // Given
        let (sut, _) = makeSUT(listings: [.stub(id: 1, categoryID: 99)])
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(sut.categoryName(for: sut.visibleListings[0]), "Autre")
    }

    // MARK: - Erreurs

    /// Une erreur doit mener à l'état `.error`.
    /// « Réessayer » (`load()`) doit permettre de s'en sortir une fois le problème résolu.
    func test_load_failure_setsErrorState_andRetrySucceeds() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        repo.listingsResult = .failure(TestError())

        // When : premier chargement en échec
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        guard case .error = sut.state else { return XCTFail("Un état d'erreur était attendu") }

        // When : l'utilisateur réessaie, le serveur répond à nouveau
        repo.listingsResult = .success([.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.visibleListings.count, 1)
    }

    /// Le message affiché à l'utilisateur est la description lisible de l'erreur,
    /// pas un message technique brut.
    func test_load_failure_exposesReadableMessage() {
        // Given
        let (sut, repo) = makeSUT(listings: [])
        repo.listingsResult = .failure(NetworkError.transport)

        // When
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(sut.state, .error(NetworkError.transport.localizedDescription))
    }
}
