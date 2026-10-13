//
//  FavoritesRepository.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
/// Persistance des favoris. Le Domain ne sait pas où ni comment ils sont stockés.
protocol FavoritesRepository {
    /// Retourne les favoris sauvegardés, ou une liste vide s'il n'y en a pas
    /// (ou si les données sont illisibles : on ne plante jamais au lancement).
    func loadFavorites() -> [Listing]
    func saveFavorites(_ listings: [Listing])
}
