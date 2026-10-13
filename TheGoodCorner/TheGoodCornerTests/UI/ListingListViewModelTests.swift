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
        listings: [Listing] = [],
        searchDebounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(20),
        pageSize: Int = 50,
        minimumVisibleCount: Int = 3
    ) -> (sut: ListingListViewModel, repo: MockListingRepository) {
        let repo = MockListingRepository()
        repo.listingsResult = .success(listings)
        repo.categoriesResult = .success([mode, maison])
        return (ListingListViewModel(repository: repo,
                                     searchDebounce: searchDebounce,
                                     pageSize: pageSize,
                                     minimumVisibleCount: minimumVisibleCount), repo)
    }

    private func makePage(_ listings: [Listing], total: Int, hasMore: Bool, page: Int = 1) -> ListingsPage {
        ListingsPage(listings: listings, page: page, total: total, hasMore: hasMore)
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

    // MARK: - Pagination

    /// La première page est demandée avec la taille de page configurée.
    func test_load_requestsFirstPageWithConfiguredPageSize() {
        // Given
        let (sut, repo) = makeSUT(pageSize: 25)

        // When
        sut.load()
        waitForLoadToFinish(sut)

        // Then
        XCTAssertEqual(repo.receivedPages, [1])
        XCTAssertEqual(repo.receivedLimits, [25])
    }

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

    /// Quand le serveur n'a plus de page (`has_more` faux), l'app ne demande plus rien.
    func test_loadMore_whenNoMorePages_doesNotRequestAnything() {
        // Given
        let (sut, repo) = makeSUT()
        repo.pagesByNumber[1] = .success(makePage([.stub(id: 1)], total: 1, hasMore: false))
        sut.load()
        waitForLoadToFinish(sut)

        // When
        sut.loadMoreIfNeeded(currentItem: sut.visibleListings[0])
        spin(for: 0.1)

        // Then
        XCTAssertEqual(repo.receivedPages, [1])
    }

    /// Une ligne loin de la fin de la liste ne doit pas déclencher de chargement.
    func test_loadMoreIfNeeded_ignoresItemsFarFromTheEnd() {
        // Given
        let (sut, repo) = makeSUT()
        let firstPage = (1...20).map { Listing.stub(id: $0) }
        repo.pagesByNumber[1] = .success(makePage(firstPage, total: 40, hasMore: true))
        sut.load()
        waitForLoadToFinish(sut)

        // When
        sut.loadMoreIfNeeded(currentItem: sut.visibleListings[0])
        spin(for: 0.1)

        // Then
        XCTAssertEqual(repo.receivedPages, [1])
    }

    /// Une page qui échoue ne doit pas vider la liste ni relancer de requête en boucle :
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
        XCTAssertFalse(sut.isLoadingMore)

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

    /// Le filtre se fait côté app : si une catégorie ne remplit pas l'écran,
    /// l'app charge les pages suivantes jusqu'à avoir assez d'annonces (ou la fin de la liste).
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

    /// Si une page échoue pendant ce chargement automatique, l'app s'arrête : pas de boucle infinie.
    func test_autoLoad_whenPageFails_stopsInsteadOfLooping() {
        // Given
        let (sut, repo) = makeSUT(minimumVisibleCount: 5)
        repo.pagesByNumber[1] = .success(makePage([.stub(id: 1, categoryID: 4)], total: 3, hasMore: true))
        repo.pagesByNumber[2] = .failure(TestError())
        sut.load()
        waitForLoadToFinish(sut)

        // When
        sut.selectedCategory = mode
        spin(until: sut.loadMoreFailed)
        spin(for: 0.1)

        // Then : une seule tentative pour la page 2
        XCTAssertEqual(repo.receivedPages, [1, 2])
    }

    /// Une nouvelle recherche annule la page en cours de chargement : sa réponse tardive
    /// ne doit pas s'ajouter aux résultats de la recherche.
    func test_newSearch_cancelsPendingNextPage_andResetsPagination() {
        // Given : la page 2 est lente (rien n'est émis pour l'instant)
        let (sut, repo) = makeSUT()
        repo.pagesByNumber[1] = .success(makePage([.stub(id: 1), .stub(id: 2)], total: 10, hasMore: true))
        let slowPage = PassthroughSubject<ListingsPage, Error>()
        repo.subjectsByPage[2] = slowPage
        repo.listingsByQuery["vel"] = [.stub(id: 9)]
        sut.load()
        waitForLoadToFinish(sut)

        sut.loadMoreIfNeeded(currentItem: sut.visibleListings[1])
        spin(until: sut.isLoadingMore)

        // When : l'utilisateur lance une recherche pendant le chargement
        sut.searchText = "vel"
        spin(until: sut.visibleListings.map(\.id) == [9])

        // La réponse tardive de la page 2 arrive après coup
        slowPage.send(makePage([.stub(id: 99)], total: 10, hasMore: false, page: 2))
        spin(for: 0.1)

        // Then : elle a été ignorée
        XCTAssertEqual(sut.visibleListings.map(\.id), [9])
        XCTAssertFalse(sut.isLoadingMore)
        XCTAssertFalse(sut.hasMore)
    }

    // MARK: - Compteurs de catégories

    /// « Toutes » est exact dès la première page (le total vient du serveur).
    /// Les autres catégories sont comptées sur ce qui est chargé : « n+ » tant qu'il reste des pages,
    /// puis le chiffre exact en fin de chargement.
    func test_categoryCounts_showPlusWhilePagesRemain_andExactWhenComplete() {
        // Given
        let (sut, repo) = makeSUT()
        let animaux = ListingCategory(id: 10, name: "Animaux")
        repo.pagesByNumber[1] = .success(makePage([.stub(id: 1, categoryID: 2),
                                                   .stub(id: 2, categoryID: 2),
                                                   .stub(id: 3, categoryID: 4)],
                                                  total: 5, hasMore: true))
        repo.pagesByNumber[2] = .success(makePage([.stub(id: 4, categoryID: 2), .stub(id: 5, categoryID: 4)],
                                                  total: 5, hasMore: false, page: 2))
        sut.load()
        waitForLoadToFinish(sut)

        // Then : une page sur deux chargée
        XCTAssertEqual(sut.allCategoriesCountText, "5")
        XCTAssertEqual(sut.countText(for: mode), "2+")
        XCTAssertEqual(sut.countText(for: maison), "1+")
        XCTAssertNil(sut.countText(for: animaux))   // rien trouvé, mais il reste des pages : on ne sait pas

        // When : tout est chargé
        sut.loadMoreIfNeeded(currentItem: sut.visibleListings[2])
        spin(until: !sut.hasMore)

        // Then : les chiffres deviennent exacts
        XCTAssertEqual(sut.countText(for: mode), "3")
        XCTAssertEqual(sut.countText(for: maison), "2")
        XCTAssertEqual(sut.countText(for: animaux), "0")
    }
}
