//
//  UserDefaultsFavoritesStore.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation

/// Stocke les favoris dans `UserDefaults`, encodés en JSON.
/// `defaults` et `key` sont injectables pour que les tests n'utilisent pas les vrais réglages.
final class UserDefaultsFavoritesStore: FavoritesRepository {

    private let defaults: UserDefaults
    private let key: String

    /// Le `v1` de la clé permet de changer le format plus tard sans lire d'anciennes données.
    init(defaults: UserDefaults = .standard, key: String = "favorites.listings.v1") {
        self.defaults = defaults
        self.key = key
    }

    func loadFavorites() -> [Listing] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Listing].self, from: data)) ?? []
    }

    func saveFavorites(_ listings: [Listing]) {
        guard let data = try? JSONEncoder().encode(listings) else { return }
        defaults.set(data, forKey: key)
    }
}
