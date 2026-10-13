//
//  ListingListView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import SwiftUI

struct ListingListView: View {
    @StateObject private var viewModel: ListingListViewModel

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: @autoclosure @escaping () -> ListingListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Annonces")
                .searchable(text: $viewModel.searchText, prompt: "Rechercher une annonce")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: toggleAppearance) {
                            Image(systemName: colorScheme == .dark ? "sun.max" : "moon")
                        }
                        .accessibilityLabel(colorScheme == .dark ? "Passer en mode clair" : "Passer en mode sombre")
                    }
                }
                .navigationDestination(for: Listing.self) { listing in
                    ListingDetailsView(listing: listing,
                                       categoryName: viewModel.categoryName(for: listing))
                }
        }
        .onAppear { viewModel.loadIfNeeded() }
    }

    // MARK: - Contenu

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
        case .error(let message):
            ErrorView(message: message, retry: viewModel.load)
        case .loaded:
            VStack(spacing: 0) {
                CategoryFilterView(categories: viewModel.categories,
                                   allCountText: viewModel.allCategoriesCountText,
                                   countText: viewModel.countText(for:),
                                   selection: $viewModel.selectedCategory)
                searchProgress
                results
            }
        }
    }

    /// Liste, ou ce qu'il faut montrer quand la liste visible est vide.
    @ViewBuilder
    private var results: some View {
        if !viewModel.visibleListings.isEmpty {
            list
        } else if isStillLookingForCategoryResults {
            searchingMoreView
        } else if viewModel.loadMoreFailed {
            EmptyStateView(title: "Chargement interrompu",
                           message: "Impossible de charger la suite des annonces.",
                           actionTitle: "Réessayer",
                           action: viewModel.retryLoadMore)
        } else {
            emptyState
        }
    }

    /// Une catégorie est choisie, rien n'est encore trouvé et le serveur a d'autres pages :
    /// le view model les charge tout seul, il ne faut pas afficher « Aucune annonce » trop tôt.
    private var isStillLookingForCategoryResults: Bool {
        viewModel.selectedCategory != nil && viewModel.hasMore && !viewModel.loadMoreFailed
    }

    private var searchingMoreView: some View {
        ProgressView("Recherche dans les annonces suivantes…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Liste et défilement infini

    private var list: some View {
        List {
            ForEach(viewModel.visibleListings) { listing in
                NavigationLink(value: listing) {
                    ListingRowView(listing: listing,
                                   categoryName: viewModel.categoryName(for: listing))
                }
                .accessibilityHint("Ouvre le détail de l'annonce")
                // Quand une ligne proche de la fin apparaît, le view model charge la page suivante.
                .onAppear { viewModel.loadMoreIfNeeded(currentItem: listing) }
            }
            footer
        }
        .listStyle(.plain)
    }

    /// Pied de liste : indicateur pendant le chargement d'une page, « Réessayer » si elle a échoué.
    @ViewBuilder
    private var footer: some View {
        if viewModel.isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .listRowSeparator(.hidden)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Chargement d'autres annonces")
        } else if viewModel.loadMoreFailed {
            VStack(spacing: 8) {
                Text("Impossible de charger la suite des annonces.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Réessayer", action: viewModel.retryLoadMore)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Recherche

    /// Barre fine pendant une recherche. Elle réserve toujours sa place
    /// (opacité) pour que la liste ne saute pas quand elle apparaît.
    private var searchProgress: some View {
        ProgressView()
            .progressViewStyle(.linear)
            .padding(.horizontal)
            .opacity(viewModel.isSearching ? 1 : 0)
            .accessibilityHidden(!viewModel.isSearching)
            .accessibilityLabel("Recherche en cours")
    }

    private var trimmedSearch: String {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !trimmedSearch.isEmpty {
            EmptyStateView(
                title: "Aucun résultat",
                message: noResultsMessage,
                actionTitle: "Effacer la recherche"
            ) {
                viewModel.searchText = ""
            }
        } else if let category = viewModel.selectedCategory {
            EmptyStateView(
                title: "Aucune annonce",
                message: "Il n'y a pas d'annonce dans la catégorie « \(category.name) ».",
                actionTitle: "Voir toutes les annonces"
            ) {
                viewModel.selectedCategory = nil
            }
        } else {
            EmptyStateView(
                title: "Aucune annonce pour le moment",
                message: "Revenez un peu plus tard.",
                actionTitle: "Actualiser",
                action: viewModel.load
            )
        }
    }

    private var noResultsMessage: String {
        if let category = viewModel.selectedCategory {
            return "Aucune annonce « \(trimmedSearch) » dans la catégorie « \(category.name) »."
        }
        return "Aucune annonce ne correspond à « \(trimmedSearch) »."
    }

    // MARK: - Apparence

    private func toggleAppearance() {
        let next: AppearanceMode = (colorScheme == .dark) ? .light : .dark
        appearanceRaw = next.rawValue
    }
}
