//
//  FavoritesView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
import SwiftUI

/// Les annonces mises en favori, la dernière ajoutée en premier.
/// Fonctionne sans réseau : les annonces viennent de la copie stockée.
struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesViewModel

    /// Fournie par l'écran des annonces (qui connaît les catégories).
    let categoryName: (Listing) -> String

    var body: some View {
        Group {
            if favorites.favorites.isEmpty {
                EmptyStateView(
                    title: "Aucun favori",
                    message: "Touchez le cœur d'une annonce pour la retrouver ici."
                )
            } else {
                list
            }
        }
        .navigationTitle("Mes favoris")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var list: some View {
        List(favorites.favorites) { listing in
            NavigationLink(value: listing) {
                ListingRowView(listing: listing,
                               categoryName: categoryName(listing),
                               isFavorite: true,
                               onToggleFavorite: { favorites.toggle(listing) })
            }
            .accessibilityHint("Ouvre le détail de l'annonce")
            .favoriteAccessibilityAction(isFavorite: true) { favorites.toggle(listing) }
        }
        .listStyle(.plain)
    }
}
