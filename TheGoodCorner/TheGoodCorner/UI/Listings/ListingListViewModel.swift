//
//  ListingListViewModel.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Combine
import Foundation

@MainActor
final class ListingListViewModel: ObservableObject {

    // MARK: - État exposé à la vue

    @Published private(set) var state: ViewState = .loading
    @Published private(set) var visibleListings: [Listing] = []
    @Published private(set) var categories: [ListingCategory] = []

    /// Vrai pendant une recherche : la liste précédente reste affichée en attendant le résultat.
    @Published private(set) var isSearching = false

    /// Erreur **locale** d'une recherche qui a échoué. N'écrase pas `state` : la liste reste visible.
    @Published private(set) var searchError: String?

    /// Vrai pendant le chargement d'une page supplémentaire.
    @Published private(set) var isLoadingMore = false

    /// Vrai si la page suivante a échoué : la liste reste affichée et la vue propose « Réessayer ».
    @Published private(set) var loadMoreFailed = false

    /// Il reste des pages à charger côté serveur.
    @Published private(set) var hasMore = false

    /// Nombre total de résultats côté serveur pour la liste chargée (exact dès la première page).
    @Published private(set) var totalCount = 0

    /// nil = toutes les catégories. Le filtre est appliqué côté app (l'API n'a pas de paramètre de catégorie).
    @Published var selectedCategory: ListingCategory?

    /// Texte tapé dans le champ de recherche. Il est envoyé au serveur après un debounce.
    @Published var searchText = ""

    // MARK: - Privé

    /// Toutes les annonces chargées jusqu'ici, dans l'ordre de l'API.
    @Published private var allListings: [Listing] = []

    private let repository: ListingRepository
    private let pageSize: Int
    private let minimumVisibleCount: Int
    private let prefetchDistance = 5

    /// Texte de recherche voulu par l'utilisateur (dernier texte, après debounce).
    private var currentQuery = ""

    /// Texte de recherche qui a produit `allListings`, `nextPage`, `hasMore` et `totalCount`.
    /// Il diffère de `currentQuery` pendant une recherche ou après un échec : c'est toujours lui
    /// qu'on utilise pour demander la page suivante, afin de ne jamais mélanger deux recherches.
    private var loadedQuery = ""

    private var nextPage = 2
    private var hasStartedLoading = false

    /// Réassigner ces propriétés annule la requête en cours.
    private var loadCancellable: AnyCancellable?
    private var loadMoreCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init(repository: ListingRepository,
         searchDebounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
         pageSize: Int = 50,
         minimumVisibleCount: Int = 10) {
        self.repository = repository
        self.pageSize = pageSize
        self.minimumVisibleCount = minimumVisibleCount

        // Le filtre se recalcule dès que la liste ou la catégorie change ; `filter` ne réordonne pas.
        Publishers.CombineLatest($allListings, $selectedCategory)
            .map { listings, category in
                guard let category else { return listings }
                return listings.filter { $0.categoryID == category.id }
            }
            .assign(to: &$visibleListings)

        // Un filtre peut laisser une liste trop courte pour défiler : on charge alors la suite.
        $selectedCategory
            .dropFirst()
            .sink { [weak self] category in self?.loadMoreIfListIsShort(for: category) }
            .store(in: &cancellables)

        // Recherche : texte nettoyé, valeur initiale et répétitions ignorées, puis debounce.
        $searchText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: searchDebounce, scheduler: DispatchQueue.main)
            .sink { [weak self] query in self?.search(query) }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func loadIfNeeded() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true
        load()
    }

    /// Chargement depuis la première page (premier affichage ou « Réessayer ») : écran de chargement.
    func load() {
        fetchFirstPage(showsFullScreenLoading: true)
    }

    /// « Réessayer » après l'échec d'une recherche : relance le dernier texte voulu.
    /// Indispensable : retaper le même texte ne ferait rien (`removeDuplicates`).
    func retrySearch() {
        searchError = nil
        fetchFirstPage(showsFullScreenLoading: false)
    }

    /// Appelé par chaque ligne qui apparaît : charge la page suivante quand on approche de la fin.
    func loadMoreIfNeeded(currentItem listing: Listing) {
        guard let index = visibleListings.firstIndex(where: { $0.id == listing.id }),
              index >= visibleListings.count - prefetchDistance else { return }
        loadMore()
    }

    /// « Réessayer » après l'échec d'une page.
    func retryLoadMore() {
        loadMoreFailed = false
        loadMore()
    }

    func categoryName(for listing: Listing) -> String {
        categories.first { $0.id == listing.categoryID }?.name ?? "Autre"
    }

    // MARK: - Compteurs

    /// « Toutes » : le total est fourni par le serveur, donc exact dès la première page.
    var allCategoriesCountText: String { String(totalCount) }

    /// Le serveur ne compte pas par catégorie : on compte ce qui est chargé.
    /// Tant qu'il reste des pages, le chiffre est un minimum (« 12+ ») ; il devient exact en fin de chargement.
    func countText(for category: ListingCategory) -> String? {
        let count = allListings.filter { $0.categoryID == category.id }.count
        if hasMore { return count == 0 ? nil : "\(count)+" }
        return String(count)
    }

    // MARK: - Chargement

    private func search(_ query: String) {
        currentQuery = query
        searchError = nil

        guard query != loadedQuery else {
        // Retour au texte déjà affiché : on abandonne la recherche en cours, s'il y en a une.
            if isSearching {
                loadCancellable = nil
                isSearching = false
            }
            return
        }
        fetchFirstPage(showsFullScreenLoading: false)
    }

    private func fetchFirstPage(showsFullScreenLoading: Bool) {
        // Une nouvelle première page rend toute page en cours inutile : on l'annule.
        loadMoreCancellable = nil
        isLoadingMore = false
        loadMoreFailed = false

        if showsFullScreenLoading {
            state = .loading
        } else {
            isSearching = true
        }

        let query = currentQuery

        loadCancellable = Publishers.Zip(
            repository.fetchListings(page: 1, limit: pageSize, query: Self.nilIfEmpty(query)),
            categoriesPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard case .failure(let error) = completion, let self else { return }
            self.isSearching = false

            // Écran d'erreur seulement si l'écran est déjà en chargement plein écran, ou si on
            // revient à la liste complète. Sinon (recherche en échec) : erreur locale, la liste reste.
            if showsFullScreenLoading || query.isEmpty {
                self.state = .error(error.localizedDescription)
            } else {
                self.searchError = error.localizedDescription
            }
        } receiveValue: { [weak self] page, categories in
            guard let self else { return }
            self.loadedQuery = query
            self.searchError = nil
            self.categories = categories
            self.hasMore = page.hasMore
            self.nextPage = 2
            self.totalCount = page.total
            self.isSearching = false
            self.state = .loaded
            self.allListings = page.listings
            self.loadMoreIfListIsShort(for: self.selectedCategory)
        }
    }

    private func loadMore() {
        guard hasMore, !isLoadingMore, !loadMoreFailed, !isSearching, state == .loaded else { return }
        isLoadingMore = true
        let requestedPage = nextPage
        let query = loadedQuery

        loadMoreCancellable = repository.fetchListings(page: requestedPage, limit: pageSize,
                                                       query: Self.nilIfEmpty(query))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard case .failure = completion else { return }
                self?.isLoadingMore = false
                self?.loadMoreFailed = true
            } receiveValue: { [weak self] page in
                guard let self else { return }
                self.hasMore = page.hasMore
                self.nextPage = requestedPage + 1
                self.totalCount = page.total
                self.isLoadingMore = false
                self.allListings = Self.merged(self.allListings, with: page.listings)
                self.loadMoreIfListIsShort(for: self.selectedCategory)
            }
    }

    /// Avec un filtre actif, la liste visible peut être trop courte pour déclencher le défilement.
    /// On charge alors la page suivante. En cas d'échec, `loadMoreFailed` bloque la boucle.
    private func loadMoreIfListIsShort(for category: ListingCategory?) {
        guard let category else { return }
        let visibleCount = allListings.filter { $0.categoryID == category.id }.count
        guard visibleCount < minimumVisibleCount else { return }
        loadMore()
    }

    // MARK: - Aides

    private static func nilIfEmpty(_ text: String) -> String? { text.isEmpty ? nil : text }

    /// Les catégories ne dépendent pas de la recherche : on ne les redemande qu'une fois.
    private func categoriesPublisher() -> AnyPublisher<[ListingCategory], Error> {
        guard categories.isEmpty else {
            return Just(categories).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        return repository.fetchCategories()
    }

    /// Ajoute les nouvelles annonces sans doublon (par identifiant), en gardant l'ordre de l'API.
    private static func merged(_ existing: [Listing], with new: [Listing]) -> [Listing] {
        var seen = Set(existing.map(\.id))
        return existing + new.filter { seen.insert($0.id).inserted }
    }
}
