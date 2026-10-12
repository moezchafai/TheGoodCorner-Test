//
//  ListingListViewModel.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//


import Combine
import Foundation

final class ListingListViewModel: ObservableObject {

    // MARK: - État exposé à la vue

    @Published private(set) var state: ViewState = .loading
    @Published private(set) var visibleListings: [Listing] = []
    @Published private(set) var categories: [ListingCategory] = []

    /// Vrai pendant une recherche : la liste précédente reste affichée en attendant le résultat.
    @Published private(set) var isSearching = false

    /// nil = toutes les catégories. Le filtre est appliqué côté app (l'API n'a pas de paramètre de catégorie).
    @Published var selectedCategory: ListingCategory?

    /// Texte tapé dans le champ de recherche. Il est envoyé au serveur après un debounce.
    @Published var searchText = ""

    // MARK: - Privé

    @Published private var allListings: [Listing] = []

    private let repository: ListingRepository
    private var currentQuery = ""
    private var hasStartedLoading = false

    /// Réassigner cette propriété annule la requête en cours : c'est ce qui coupe
    /// l'ancienne recherche quand le texte change.
    private var loadCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    /// `searchDebounce` est un paramètre pour que les tests puissent l'écourter.
    init(repository: ListingRepository,
         searchDebounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300)) {
        self.repository = repository

        // Le filtre par catégorie se recalcule dès que la liste ou la catégorie change.
        // `filter` ne réordonne pas : l'ordre de l'API est conservé.
        Publishers.CombineLatest($allListings, $selectedCategory)
            .map { listings, category in
                guard let category else { return listings }
                return listings.filter { $0.categoryID == category.id }
            }
            .assign(to: &$visibleListings)

        // Recherche : on nettoie le texte, on ignore la valeur initiale et les répétitions,
        // puis on attend que l'utilisateur arrête de taper.
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

    /// Chargement complet (premier affichage ou « Réessayer ») : écran de chargement.
    func load() {
        fetch(showsFullScreenLoading: true)
    }

    func categoryName(for listing: Listing) -> String {
        categories.first { $0.id == listing.categoryID }?.name ?? "Autre"
    }

    // MARK: - Privé

    private func search(_ query: String) {
// Revenir au texte déjà chargé (par exemple « a » puis effacer) ne doit pas relancer de requête.
        guard query != currentQuery else { return }
        currentQuery = query
        fetch(showsFullScreenLoading: false)
    }

    private func fetch(showsFullScreenLoading: Bool) {
        if showsFullScreenLoading {
            state = .loading
        } else {
            isSearching = true
        }

        let query = currentQuery.isEmpty ? nil : currentQuery

        loadCancellable = Publishers.Zip(repository.fetchListings(query: query),
                                         categoriesPublisher())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                self?.isSearching = false
                self?.state = .error(error.localizedDescription)
            } receiveValue: { [weak self] listings, categories in
                self?.allListings = listings
                self?.categories = categories
                self?.isSearching = false
                self?.state = .loaded
            }
    }

    /// Les catégories ne dépendent pas de la recherche : on ne les redemande au serveur que tant qu'on ne les a pas.
    private func categoriesPublisher() -> AnyPublisher<[ListingCategory], Error> {
        guard categories.isEmpty else {
            return Just(categories).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        return repository.fetchCategories()
    }
}
