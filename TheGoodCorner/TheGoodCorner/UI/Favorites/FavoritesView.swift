//
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
///
/// **Note :** dans cet écran, les cartes ne sont **pas cliquables** :
/// l'utilisateur gère ses favoris (ajout/retrait via le cœur), mais
/// l'ouverture du détail se fait depuis la liste principale.
struct FavoritesView: View {

    @EnvironmentObject private var favorites: FavoritesViewModel

    /// Fournie par l'écran des annonces (qui connaît les catégories).
    let categoryName: (Listing) -> String

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: DesignTokens.Spacing.listSpacing
            ) {
                FavoritesHeaderView(count: favorites.count)
                    .padding(.bottom, 4)

                if favorites.favorites.isEmpty {
                    emptyState
                } else {
                    ForEach(favorites.favorites) { listing in
                        ListingCardView(
                            listing: listing,
                            categoryName: categoryName(listing),
                            isFavorite: true,
                            onToggleFavorite: { favorites.toggle(listing) }
                        )
                        .favoriteAccessibilityAction(isFavorite: true) {
                            favorites.toggle(listing)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.screenBackground)
        .navigationTitle("Mes favoris")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .accessibilityHidden(true)

            Text("Aucun favori pour l'instant")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Touchez le cœur sur une annonce pour la retrouver ici.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
    }
}
