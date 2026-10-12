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

    init(viewModel: @autoclosure @escaping () -> ListingListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Annonces")
                .searchable(text: $viewModel.searchText, prompt: "Rechercher une annonce")
                .navigationDestination(for: Listing.self) { listing in
                    ListingDetailsView(listing: listing,
                                       categoryName: viewModel.categoryName(for: listing))
                }
        }
        .onAppear { viewModel.loadIfNeeded() }
        .tint(Color.brandBlueDark)
    }

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
                                   selection: $viewModel.selectedCategory)
                searchProgress
                if viewModel.visibleListings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
    }

    private var list: some View {
        List(viewModel.visibleListings) { listing in
            NavigationLink(value: listing) {
                ListingRowView(listing: listing,
                               categoryName: viewModel.categoryName(for: listing))
            }
            .accessibilityHint("Ouvre le détail de l'annonce")
        }
        .listStyle(.plain)
        .background(Color.screenBackground)
    }

    // Barre fine pendant une recherche. Elle réserve toujours sa place
     // (opacité) pour que la liste ne saute pas quand elle apparaît.
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
}
