//
//  ListingListViewModel.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import Combine

final class ListingListViewModel: ObservableObject {

    @Published private(set) var state: ViewState = .loading
    @Published private(set) var visibleListings: [Listing] = []
    @Published private(set) var categories: [ListingCategory] = []
    @Published var selectedCategory: ListingCategory?

    @Published private var allListings: [Listing] = []

    private let repository: ListingRepository
    private var loadCancellable: AnyCancellable?
    private var hasStartedLoading = false

    init(repository: ListingRepository) {
        self.repository = repository

    
        Publishers.CombineLatest($allListings, $selectedCategory)
            .map { listings, category in
                guard let category else { return listings }
                return listings.filter { $0.categoryID == category.id }
            }
            .assign(to: &$visibleListings)
    }

    func loadIfNeeded() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true
        load()
    }

    func load() {
        state = .loading
        loadCancellable = Publishers.Zip(repository.fetchListings(),
                                         repository.fetchCategories())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.state = .error(error.localizedDescription)
                }
            } receiveValue: { [weak self] listings, categories in
                self?.allListings = listings
                self?.categories = categories
                self?.state = .loaded
            }
    }

    func categoryName(for listing: Listing) -> String {
        categories.first { $0.id == listing.categoryID }?.name ?? "Autre"
    }
}
