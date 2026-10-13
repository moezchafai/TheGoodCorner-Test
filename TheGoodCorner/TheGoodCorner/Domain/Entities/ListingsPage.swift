//
//  ListingsPage.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
/// Une page d'annonces, avec ce dont l'app a besoin pour demander la suivante.
struct ListingsPage: Equatable {
    let listings: [Listing]
    /// Numéro de la page (à partir de 1).
    let page: Int
    /// Nombre total de résultats côté serveur (pour la recherche en cours).
    let total: Int
    let hasMore: Bool
}
