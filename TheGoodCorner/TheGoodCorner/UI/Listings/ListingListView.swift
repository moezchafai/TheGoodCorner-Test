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
        }
        .onAppear { viewModel.loadIfNeeded() }
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
            ListingRowView(listing: listing,
                           categoryName: viewModel.categoryName(for: listing))
        }
        .listStyle(.plain)
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
