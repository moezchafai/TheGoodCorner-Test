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

    /// Message d'erreur **local** d'une recherche qui a échoué.
    /// N'écrase pas `state` : la liste déjà affichée reste visible.
    @Published private(set) var searchError: String?

    /// Vrai pendant le chargement d'une page supplémentaire.
    @Published private(set) var isLoadingMore = false

    /// Vrai si la page suivante a échoué : la liste reste affichée et la vue propose « Réessayer ».
    @Published private(set) var loadMoreFailed = false

    /// Il reste des pages à charger côté serveur.
    @Published private(set) var hasMore = false

    /// Nombre total de résultats côté serveur pour la recherche en cours (exact dès la première page).
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

    private var currentQuery = ""
    private var nextPage = 2
    private var hasStartedLoading = false

    /// Réassigner ces propriétés annule la requête en cours : c'est ce qui coupe
    /// une recherche ou une page devenue inutile.
    private var loadCancellable: AnyCancellable?
    private var loadMoreCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    /// Les paramètres ont des valeurs par défaut : l'app ne change rien,
    /// les tests peuvent écourter le debounce et la taille des pages.
    init(repository: ListingRepository,
         searchDebounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
         pageSize: Int = 50,
         minimumVisibleCount: Int = 10) {
        self.repository = repository
        self.pageSize = pageSize
        self.minimumVisibleCount = minimumVisibleCount

        // Le filtre par catégorie se recalcule dès que la liste ou la catégorie change.
        // `filter` ne réordonne pas : l'ordre de l'API est conservé.
        Publishers.CombineLatest($allListings, $selectedCategory)
            .map { listings, category in
                guard let category else { return listings }
                return listings.filter { $0.categoryID == category.id }
            }
            .assign(to: &$visibleListings)

        // Changer de catégorie peut laisser une liste trop courte pour défiler :
        // on charge alors la page suivante sans attendre.
        $selectedCategory
            .dropFirst()
            .sink { [weak self] category in self?.loadMoreIfListIsShort(for: category) }
            .store(in: &cancellables)

        // Recherche : on nettoie le texte, on ignore la valeur initiale et les répétitions,
        // puis on attend que l'utilisateur arrête de taper.
        $searchText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: searchDebounce, scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.searchError = nil   // on efface l'erreur précédente
                self?.search(query)
            }
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
    /// Retourne nil quand on ne sait rien (0 trouvé, mais il reste des pages).
    func countText(for category: ListingCategory) -> String? {
        let count = allListings.filter { $0.categoryID == category.id }.count
        if hasMore { return count == 0 ? nil : "\(count)+" }
        return String(count)
    }

    // MARK: - Chargement

    private func search(_ query: String) {
        // Revenir au texte déjà chargé ne doit pas relancer de requête.
        guard query != currentQuery else { return }
        currentQuery = query
        fetchFirstPage(showsFullScreenLoading: false)
    }

    private func fetchFirstPage(showsFullScreenLoading: Bool) {
        // Une nouvelle recherche rend toute page en cours inutile : on l'annule.
        loadMoreCancellable = nil
        isLoadingMore = false
        loadMoreFailed = false

        if showsFullScreenLoading {
            state = .loading
        } else {
            isSearching = true
        }

        loadCancellable = Publishers.Zip(
            repository.fetchListings(page: 1, limit: pageSize, query: queryOrNil),
            categoriesPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard case .failure(let error) = completion else { return }
            guard let self else { return }
            self.isSearching = false

            if self.currentQuery.isEmpty {
                // Échec du chargement initial → écran d'erreur
                self.state = .error(error.localizedDescription)
            } else {
                // Échec d'une recherche → on garde la liste et on affiche un message local
                self.searchError = error.localizedDescription
            }
        } receiveValue: { [weak self] page, categories in
            guard let self else { return }
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

        loadMoreCancellable = repository.fetchListings(page: requestedPage, limit: pageSize, query: queryOrNil)
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

    private var queryOrNil: String? { currentQuery.isEmpty ? nil : currentQuery }

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
