//
//  FavoritesViewModel.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation


/// Source de vérité des favoris, partagée par toute l'app.
/// Le dernier favori ajouté apparaît en premier, et chaque changement est sauvegardé tout de suite.
final class FavoritesViewModel: ObservableObject {

    @Published private(set) var favorites: [Listing]

    private let repository: FavoritesRepository

    init(repository: FavoritesRepository) {
        self.repository = repository
        self.favorites = repository.loadFavorites()
    }

    var count: Int { favorites.count }

    /// Une annonce est identifiée par son `id` : la copie stockée peut être plus ancienne
    /// que celle que renvoie l'API, ce qui ne change pas le fait qu'elle soit en favori.
    func isFavorite(_ listing: Listing) -> Bool {
        favorites.contains { $0.id == listing.id }
    }

    /// Ajoute l'annonce (en tête de liste) ou la retire si elle y est déjà.
    func toggle(_ listing: Listing) {
        if let index = favorites.firstIndex(where: { $0.id == listing.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(listing, at: 0)
        }
        repository.saveFavorites(favorites)
    }
}
