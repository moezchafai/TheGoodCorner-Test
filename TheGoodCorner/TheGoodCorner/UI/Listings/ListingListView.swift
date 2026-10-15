//
//  ListingListView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//


import SwiftUI

struct ListingListView: View {

    // MARK: - Dependencies

    @ObservedObject var viewModel: ListingListViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var favorites: FavoritesViewModel

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .navigationTitle("Annonces")
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Rechercher une annonce"
            )
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    favoritesButton
                    Button(action: toggleAppearance) {
                        Image(systemName: colorScheme == .dark ? "sun.max" : "moon")
                    }
                    .accessibilityLabel(colorScheme == .dark ? "Passer en mode clair" : "Passer en mode sombre")
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
                searchErrorBanner
                results
            }
            .background(Color.screenBackground)
        }
    }

    /// Liste, ou ce qu'il faut montrer quand la liste visible est vide.
    /// L'ordre des cas compte : une recherche en échec ne doit jamais passer pour « aucun résultat ».
    @ViewBuilder
    private var results: some View {
        if !viewModel.visibleListings.isEmpty {
            list
        } else if viewModel.searchError != nil {
            EmptyStateView(title: "Recherche impossible",
                           message: "La recherche n'a pas pu aboutir. Vérifiez votre connexion.",
                           actionTitle: "Réessayer",
                           action: viewModel.retrySearch)
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

    // MARK: - Liste (floating cards)

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.listSpacing) {
                ForEach(viewModel.visibleListings) { listing in
                    NavigationLink(value: AppRoute.details(listing)) {
                        ListingCardView(
                            listing: listing,
                            categoryName: viewModel.categoryName(for: listing),
                            isFavorite: favorites.isFavorite(listing),
                            onToggleFavorite: { favorites.toggle(listing) }
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Ouvre le détail de l'annonce")
                    .favoriteAccessibilityAction(isFavorite: favorites.isFavorite(listing)) {
                        favorites.toggle(listing)
                    }
                    // Quand une ligne proche de la fin apparaît, le view model charge la page suivante.
                    .onAppear { viewModel.loadMoreIfNeeded(currentItem: listing) }
                }

                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color.screenBackground)
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
            .padding(.vertical, 12)
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
            .padding(.vertical, 12)
        }
    }

    // MARK: - Recherche

    /// Barre fine pendant une recherche. Elle réserve toujours sa place (opacité)
    /// pour que la liste ne saute pas quand elle apparaît.
    private var searchProgress: some View {
        ProgressView()
            .progressViewStyle(.linear)
            .padding(.horizontal)
            .opacity(viewModel.isSearching ? 1 : 0)
            .accessibilityHidden(!viewModel.isSearching)
            .accessibilityLabel("Recherche en cours")
    }

    /// Bandeau discret affiché quand une recherche échoue alors qu'une liste est affichée :
    /// la liste reste visible et « Réessayer » relance la recherche.
    /// Si la liste est vide, c'est l'écran « Recherche impossible » qui prend le relais.
    @ViewBuilder
    private var searchErrorBanner: some View {
        if viewModel.searchError != nil && !viewModel.visibleListings.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("Recherche impossible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Réessayer") {
                    viewModel.retrySearch()
                }
                .font(.caption.weight(.semibold))
                .accessibilityLabel("Réessayer la recherche")
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.08))
        }
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

    // MARK: - Favoris (toolbar)

    /// Le bouton « Favoris » demande au coordinateur d'empiler l'écran des favoris.
    private var favoritesButton: some View {
        Button(action: coordinator.showFavorites) {
            Image(systemName: "heart")
                .foregroundStyle(Color.brandBlue)
                .overlay(alignment: .topTrailing) { favoritesBadge }
        }
        .accessibilityLabel(favoritesAccessibilityLabel)
    }

    @ViewBuilder
    private var favoritesBadge: some View {
        if favorites.count > 0 {
            Text("\(favorites.count)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.red, in: Capsule())
                .offset(x: 10, y: -8)
                .accessibilityHidden(true)   // le nombre est déjà dans le libellé du bouton
        }
    }

    private var favoritesAccessibilityLabel: String {
        switch favorites.count {
        case 0:  return "Favoris, aucune annonce"
        case 1:  return "Favoris, 1 annonce"
        default: return "Favoris, \(favorites.count) annonces"
        }
    }

    // MARK: - Apparence

    private func toggleAppearance() {
        let next: AppearanceMode = (colorScheme == .dark) ? .light : .dark
        appearanceRaw = next.rawValue
    }
}
