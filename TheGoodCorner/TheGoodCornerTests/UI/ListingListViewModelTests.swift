//
//
//  ListingListViewModelTests.swift
//  TheGoodCornerTests
//

import XCTest
import Combine
@testable import TheGoodCorner

/// Vérifie la logique de l'écran de liste, sans SwiftUI ni réseau :
/// le `MockListingRepository` renvoie des annonces préparées.
///
/// Ce que ces tests protègent : l'ordre de l'API est conservé, le filtre par catégorie
/// fonctionne côté app, la recherche est temporisée et annulable, et chaque état
/// (chargement, erreur, vide) est atteignable et récupérable.
final class ListingListViewModelTests: XCTestCase {

    private struct TestError: Error {}

    private var cancellables = Set<AnyCancellable>()

    private let mode = ListingCategory(id: 2, name: "Mode")
    private let maison = ListingCategory(id: 4, name: "Maison")

    // MARK: - Aides

    /// `searchDebounce` est court (20 ms) pour que les tests restent rapides.
    private func makeSUT(
        listings: [Listing],
        searchDebounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(20)
    ) -> (sut: ListingListViewModel, repo: MockListingRepository) {
        let repo = MockListingRepository()
        repo.listingsResult = .success(listings)
        repo.categoriesResult = .success([mode, maison])
        return (ListingListViewModel(repository: repo, searchDebounce: searchDebounce), repo)
    }

    /// Le résultat du chargement arrive via le main thread (`receive(on:)`) :
    /// on attend que l'état quitte `.loading` avant de vérifier quoi que ce soit.
    private func waitForLoadToFinish(_ sut: ListingListViewModel) {
        let exp = expectation(description: "le chargement est terminé")
        sut.$state
            .first { $0 != .loading }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        wait(for: [exp], timeout: 1)
    }

    /// Fait tourner la boucle d'événements jusqu'à ce que la condition soit vraie.
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

    /// Laisse la boucle d'événements tourner (pour vérifier qu'il ne se passe rien).
    private func spin(for seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func lastQuery(of repo: MockListingRepository) -> String? {
        repo.receivedQueries.last ?? nil
    }

    // MARK: - Chargement

    /// L'API renvoie déjà les annonces dans l'ordre d'affichage (urgentes d'abord) :
    /// l'app ne doit surtout pas les retrier. Les identifiants volontairement désordonnés
    /// (3, 1, 2) le prouvent.
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

    /// `loadIfNeeded()` est appelé à chaque apparition de l'écran :
    /// il ne doit déclencher qu'un seul appel réseau.
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
    /// Choisir une catégorie ne garde que ses annonces (dans l'ordre d'origine),
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

        // When / Then : retour à « Toutes »
        sut.selectedCategory = nil
        XCTAssertEqual(sut.visibleListings.map(\.id), [1, 2, 3])
    }

    /// Une catégorie sans annonce n'est pas une erreur : l'état reste `.loaded`
    /// et la liste est vide. C'est ce qui permet à l'écran d'afficher l'état vide intentionnel.
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

    /// Une annonce dont la catégorie n'est pas dans `/categories` ne doit pas faire planter l'écran.
    func test_categoryName_fallsBackToAutre_forUnknownCategory() {
        // Given
        let (sut, _) = makeSUT(listings: [.stub(id: 1, categoryID: 99)])
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(sut.categoryName(for: sut.visibleListings[0]), "Autre")
    }

    // MARK: - Erreurs

    /// Une erreur doit mener à l'état `.error`, et « Réessayer » (`load()`)
    /// doit permettre de s'en sortir une fois le problème résolu.
    func test_load_failure_setsErrorState_andRetrySucceeds() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        repo.listingsResult = .failure(TestError())

        // When : premier chargement en échec
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        guard case .error = sut.state else { return XCTFail("Un état d'erreur était attendu") }

        // When : l'utilisateur appuie sur « Réessayer » alors que le serveur répond à nouveau
        repo.listingsResult = .success([.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.visibleListings.count, 1)
    }

    /// Le message affiché à l'utilisateur est la description lisible de l'erreur réseau,
    /// pas un message technique.
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

    // MARK: - Recherche

    /// Taper plusieurs lettres d'affilée ne doit déclencher qu'une seule requête (debounce).
    func test_search_typingQuickly_sendsOnlyOneRequest() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)
        repo.listingsByQuery["vel"] = [.stub(id: 7)]

        // When : trois frappes successives, plus rapides que le debounce
        sut.searchText = "v"
        sut.searchText = "ve"
        sut.searchText = "vel"
        spin(until: sut.visibleListings.map(\.id) == [7])

        // Then : le chargement initial (nil), puis une seule recherche
        XCTAssertEqual(repo.receivedQueries, [nil, "vel"])
    }

    /// Le résultat du serveur remplace la liste, sans repasser par l'écran de chargement.
    func test_search_replacesListingsWithServerResults() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1), .stub(id: 2)])
        sut.load()
        waitForLoadToFinish(sut)
        repo.listingsByQuery["vélo"] = [.stub(id: 9)]

        // When
        sut.searchText = "vélo"
        spin(until: sut.visibleListings.map(\.id) == [9] && !sut.isSearching)

        // Then
        XCTAssertEqual(sut.state, .loaded)
    }

    /// Une recherche sans résultat n'est pas une erreur : le serveur répond 200 avec une liste vide.
    /// L'état reste `.loaded`, ce qui permet d'afficher « Aucun résultat ».
    func test_search_withNoResults_isNotAnError() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)
        repo.listingsByQuery["zzzzzz"] = []

        // When
        sut.searchText = "zzzzzz"
        spin(until: lastQuery(of: repo) == "zzzzzz" && !sut.isSearching)

        // Then
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertTrue(sut.visibleListings.isEmpty)
    }

    /// Effacer le champ de recherche recharge la liste complète (requête sans `query`).
    func test_search_clearingText_reloadsAllListings() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1), .stub(id: 2)])
        sut.load()
        waitForLoadToFinish(sut)
        repo.listingsByQuery["vel"] = [.stub(id: 7)]
        sut.searchText = "vel"
        spin(until: sut.visibleListings.map(\.id) == [7])

        // When
        sut.searchText = ""
        spin(until: sut.visibleListings.map(\.id) == [1, 2])

        // Then
        XCTAssertNil(lastQuery(of: repo))
    }

    /// Un champ contenant seulement des espaces ne doit pas lancer de requête.
    func test_search_withBlankText_sendsNoRequest() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)

        // When
        sut.searchText = "   "
        spin(for: 0.15)

        // Then : seul le chargement initial a eu lieu
        XCTAssertEqual(repo.receivedQueries, [nil])
    }

    /// Une erreur pendant une recherche mène à l'état `.error`, et « Réessayer »
    /// relance la recherche en cours (le texte tapé est conservé).
    func test_search_failure_setsErrorState_andRetryKeepsTheQuery() {
        // Given
        let (sut, repo) = makeSUT(listings: [.stub(id: 1)])
        sut.load()
        waitForLoadToFinish(sut)
        repo.listingsResult = .failure(TestError())

        // When : la recherche échoue
        sut.searchText = "vélo"
        spin(until: sut.state != .loaded)

        // Then
        guard case .error = sut.state else { return XCTFail("Un état d'erreur était attendu") }

        // When : « Réessayer » alors que le serveur répond à nouveau
        repo.listingsResult = .success([.stub(id: 5)])
        sut.load()
        spin(until: sut.state == .loaded)

        // Then : la même recherche a été relancée
        XCTAssertEqual(lastQuery(of: repo), "vélo")
        XCTAssertEqual(sut.visibleListings.map(\.id), [5])
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
        spin(until: lastQuery(of: repo) == "a")

        // When : l'utilisateur change de recherche avant la réponse de « a »
        sut.searchText = "b"
        spin(until: sut.visibleListings.map(\.id) == [2])

        // La réponse tardive de « a » arrive après coup
        slowRequest.send([.stub(id: 99)])
        spin(for: 0.1)

        // Then : elle a été ignorée
        XCTAssertEqual(sut.visibleListings.map(\.id), [2])
        XCTAssertFalse(sut.isSearching)
    }
}
