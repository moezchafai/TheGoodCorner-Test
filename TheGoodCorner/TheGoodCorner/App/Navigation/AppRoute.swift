//
//  AppRoute.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 15/10/2026.
//

import Foundation

/// Les destinations de l'app.
/// `Hashable` : c'est ce que `NavigationStack` exige pour mémoriser la pile.
enum AppRoute: Hashable {
    case details(Listing)
    case favorites
}
