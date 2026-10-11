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

    @ViewBuilder
    private var emptyState: some View {
        if let category = viewModel.selectedCategory {
            EmptyStateView(title: "Aucune annonce",
                           message: "Il n'y a pas d'annonce dans la catégorie « \(category.name) ».",
                           actionTitle: "Voir toutes les annonces") {
                viewModel.selectedCategory = nil
            }
        } else {
            EmptyStateView(title: "Aucune annonce pour le moment",
                           message: "Revenez un peu plus tard.",
                           actionTitle: "Actualiser",
                           action: viewModel.load)
        }
    }
}
