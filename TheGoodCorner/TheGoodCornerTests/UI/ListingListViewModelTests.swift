//
//
//  ListingListViewModelTests.swift
//  TheGoodCornerTests
//

import XCTest
import Combine
@testable import TheGoodCorner

/// Vérifie la logique de l'écran de liste, sans SwiftUI ni réseau.
/// Elle protège : l'ordre de l'API, le filtre par catégorie (côté app), la recherche temporisée
/// et annulable, et la pagination (sans doublon, sans boucle quand une page échoue).
///
@MainActor
final class ListingListViewModelTests: XCTestCase {

    private struct TestError: Error {}

    private var cancellables = Set<AnyCancellable>()

    private let mode = ListingCategory(id: 2, name: "Mode")
    private let maison = ListingCategory(id: 4, name: "Maison")

    // MARK: - Aides

    /// `searchDebounce` court (20 ms) pour que les tests restent rapides.
    private func makeSUT(
        listings: [Listing] = [],
        pageSize: Int = 50,
        minimumVisibleCount: Int = 3
    ) -> (sut: ListingListViewModel, repo: MockListingRepository) {
        let repo = MockListingRepository()
        repo.listingsResult = .success(listings)
        repo.categoriesResult = .success([mode, maison])
        let sut = ListingListViewModel(repository: repo,
                                       searchDebounce: .milliseconds(20),
                                       pageSize: pageSize,
                                       minimumVisibleCount: minimumVisibleCount)
        return (sut, repo)
    }

    private func makePage(_ listings: [Listing], total: Int, hasMore: Bool, page: Int = 1) -> ListingsPage {
        ListingsPage(listings: listings, page: page, total: total, hasMore: hasMore)
    }

    /// Le résultat arrive via le main thread : on attend la fin du chargement avant de vérifier.
    private func waitForLoadToFinish(_ sut: ListingListViewModel) {
        let exp = expectation(description: "le chargement est terminé")
        sut.$state
            .first { $0 != .loading }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        wait(for: [exp], timeout: 1)
    }

    /// Fait tourner la boucle d'événements jusqu'à ce que la condition soit vraie (ou le timeout).
    private func spin(until condition: @autoclosure () -> Bool,
                      timeout: TimeInterval = 2,
                      file: StaticString = #filePath,
                      line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), "Condition non remplie dans le délai", file: file, line: line)
    }

    /// Laisse tourner la boucle d'événements (pour vérifier qu'il ne se passe rien).
    private func spin(for seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - Chargement et filtre

    /// L'API renvoie déjà les annonces dans l'ordre d'affichage : l'app ne doit pas les retrier.
    /// Les identifiants désordonnés (3, 1, 2) le prouvent.
    func test_load_keepsAPIOrder() {
        // Given
        let (sut, _) = makeSUT(listings: [.stub(id: 3), .stub(id: 1), .stub(id: 2)])

        // When
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.visibleListings.map(\.id), [3, 1, 2])
    }

    /// L'API n'a pas de paramètre de catégorie : le filtre se fait dans l'app.
    /// Une catégorie vide n'est pas une erreur (état `.loaded`, liste vide : c'est l'état vide intentionnel),
    /// et « Toutes » (`nil`) restaure la liste complète.
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

        // When / Then : catégorie sans annonce
        sut.selectedCategory = ListingCategory(id: 9, name: "Vide")
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertTrue(sut.visibleListings.isEmpty)

        // When / Then : retour à « Toutes »
        sut.selectedCategory = nil
        XCTAssertEqual(sut.visibleListings.map(\.id), [1, 2, 3])
    }

    /// Une erreur mène à l'état `.error`, et « Réessayer » (`load()`) permet de s'en sortir.
    func test_load_failure_setsErrorState_andRetrySucceeds() {
        // Given
        let (sut, repo) = makeSUT()
        repo.listingsResult = .failure(TestError())

        // When : premier chargement en échec
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        guard case .error = sut.state else { return XCTFail("Un état d'erreur était attendu") }

        // When : le serveur répond à nouveau
        repo.listingsResult = .success([.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.visibleListings.map(\.id), [1])
    }

    // MARK: - Recherche

    /// Taper plusieurs lettres d'affilée ne déclenche qu'une seule requête (debounce).
    func test_search_typingQuickly_sendsOnlyOneRequest() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)
        repo.listingsByQuery["vel"] = [.stub(id: 7)]

        // When : trois frappes plus rapides que le debounce
        sut.searchText = "v"
        sut.searchText = "ve"
        sut.searchText = "vel"
        spin(until: sut.visibleListings.map(\.id) == [7])

        // Then : le chargement initial (nil), puis une seule recherche
        XCTAssertEqual(repo.receivedQueries, [nil, "vel"])
    }

    /// Quand le texte change, la requête précédente est annulée : une réponse lente
    /// ne doit pas écraser les résultats de la recherche plus récente.
    func test_search_cancelsPreviousRequest_whenTextChanges() {
        // Given : la recherche « a » est lente (rien n'est émis pour l'instant)
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)
        let slowRequest = PassthroughSubject<[Listing], Error>()
        repo.subjectsByQuery["a"] = slowRequest
        repo.listingsByQuery["b"] = [.stub(id: 2)]
        sut.searchText = "a"
        spin(until: repo.receivedQueries.last == "a")

        // When : l'utilisateur change de recherche avant la réponse de « a »
        sut.searchText = "b"
        spin(until: sut.visibleListings.map(\.id) == [2])
        slowRequest.send([.stub(id: 99)])   // la réponse tardive arrive après coup
        spin(for: 0.1)

        // Then : elle a été ignorée
        XCTAssertEqual(sut.visibleListings.map(\.id), [2])
        XCTAssertFalse(sut.isSearching)
    }

    // MARK: - Pagination

    /// Les pages s'empilent dans l'ordre de l'API, et une annonce déjà vue (id 2) n'est pas dupliquée.
    func test_loadMore_appendsNextPage_withoutDuplicates() {
        // Given
        let (sut, repo) = makeSUT()
        repo.pagesByNumber[1] = .success(makePage([.stub(id: 1), .stub(id: 2)], total: 4, hasMore: true))
        repo.pagesByNumber[2] = .success(makePage([.stub(id: 2), .stub(id: 3), .stub(id: 4)],
                                                  total: 4, hasMore: false, page: 2))
        sut.load()
        waitForLoadToFinish(sut)

        // When : la dernière ligne apparaît
        sut.loadMoreIfNeeded(currentItem: sut.visibleListings[1])
        spin(until: sut.visibleListings.map(\.id) == [1, 2, 3, 4])

        // Then
        XCTAssertEqual(repo.receivedPages, [1, 2])
        XCTAssertFalse(sut.hasMore)
    }

    /// Une page qui échoue ne vide pas la liste et ne relance rien en boucle :
    /// l'utilisateur voit « Réessayer », et la tentative suivante est manuelle.
    func test_loadMore_failure_keepsListings_andRetrySucceeds() {
        // Given
        let (sut, repo) = makeSUT()
        repo.pagesByNumber[1] = .success(makePage([.stub(id: 1), .stub(id: 2)], total: 3, hasMore: true))
        repo.pagesByNumber[2] = .failure(TestError())
        sut.load()
        waitForLoadToFinish(sut)

        // When : la page 2 échoue
        sut.loadMoreIfNeeded(currentItem: sut.visibleListings[1])
        spin(until: sut.loadMoreFailed)

        // Then : la liste reste affichée, sans écran d'erreur
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.visibleListings.map(\.id), [1, 2])

        // Pas de nouvelle tentative automatique
        sut.loadMoreIfNeeded(currentItem: sut.visibleListings[1])
        spin(for: 0.1)
        XCTAssertEqual(repo.receivedPages, [1, 2])

        // When : « Réessayer », le serveur répond à nouveau
        repo.pagesByNumber[2] = .success(makePage([.stub(id: 3)], total: 3, hasMore: false, page: 2))
        sut.retryLoadMore()
        spin(until: sut.visibleListings.map(\.id) == [1, 2, 3])

        // Then
        XCTAssertFalse(sut.loadMoreFailed)
    }

    /// Le filtre se fait côté app : si une catégorie ne remplit pas l'écran, l'app charge
    /// les pages suivantes jusqu'à avoir assez d'annonces (ou la fin de la liste).
    func test_selectingCategory_withShortList_loadsNextPagesAutomatically() {
        // Given : la catégorie « Mode » (2) est dispersée sur trois pages
        let (sut, repo) = makeSUT(minimumVisibleCount: 2)
        repo.pagesByNumber[1] = .success(makePage([.stub(id: 1, categoryID: 2), .stub(id: 2, categoryID: 4)],
                                                  total: 5, hasMore: true))
        repo.pagesByNumber[2] = .success(makePage([.stub(id: 3, categoryID: 4)],
                                                  total: 5, hasMore: true, page: 2))
        repo.pagesByNumber[3] = .success(makePage([.stub(id: 4, categoryID: 2), .stub(id: 5, categoryID: 2)],
                                                  total: 5, hasMore: false, page: 3))
        sut.load()
        waitForLoadToFinish(sut)

        // When
        sut.selectedCategory = mode
        spin(until: sut.visibleListings.map(\.id) == [1, 4, 5])

        // Then
        XCTAssertEqual(repo.receivedPages, [1, 2, 3])
    }
    /// Une recherche qui échoue garde la liste, montre une erreur locale (pas l'écran d'erreur),
    /// et « Réessayer » relance le même texte. Retaper le même texte ne le ferait pas (removeDuplicates).
    func test_search_failure_keepsListings_andRetryRerunsTheQuery() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)
        repo.listingsResult = .failure(TestError())

        // When : la recherche échoue
        sut.searchText = "vélo"
        spin(until: sut.searchError != nil)

        // Then : la liste reste affichée
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.visibleListings.map(\.id), [1])
        XCTAssertFalse(sut.isSearching)

        // When : « Réessayer », le serveur répond à nouveau
        repo.listingsResult = .success([.stub(id: 5)])
        sut.retrySearch()
        spin(until: sut.visibleListings.map(\.id) == [5])

        // Then
        XCTAssertNil(sut.searchError)
        XCTAssertEqual(repo.receivedQueries.last, "vélo")
    }

    /// Après une recherche en échec, la liste affichée est l'ancienne : sa page suivante doit être
    /// demandée pour l'ancien texte, pas pour celui qui a échoué (sinon les deux se mélangent).
    func test_search_failure_doesNotMixNextPageOfFailedQueryIntoOldList() {
        // Given
        let (sut, repo) = makeSUT()
        repo.pagesByNumber[1] = .success(makePage([.stub(id: 1), .stub(id: 2)], total: 3, hasMore: true))
        repo.pagesByNumber[2] = .success(makePage([.stub(id: 3)], total: 3, hasMore: false, page: 2))
        sut.load()
        waitForLoadToFinish(sut)

        let failing = PassthroughSubject<[Listing], Error>()
        repo.subjectsByQuery["vel"] = failing
        sut.searchText = "vel"
        spin(until: repo.receivedQueries.last == "vel")
        failing.send(completion: .failure(TestError()))
        spin(until: sut.searchError != nil)

        // When : l'utilisateur fait défiler l'ancienne liste jusqu'au bout
        sut.loadMoreIfNeeded(currentItem: sut.visibleListings[1])
        spin(until: sut.visibleListings.map(\.id) == [1, 2, 3])

        // Then : la page suivante a bien été demandée sans texte de recherche
        XCTAssertEqual(repo.receivedQueries, [nil, "vel", nil])
    }
}
