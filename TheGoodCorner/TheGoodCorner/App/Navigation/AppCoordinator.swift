//
//  AppCoordinator.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 15/10/2026.
//

import SwiftUI

/// Seul responsable de la navigation : quelles destinations existent,
/// comment construire chaque écran, et dans quel ordre ils sont empilés.
final class AppCoordinator: ObservableObject {

    /// Pile de navigation.
    /// Un tableau (et non un `NavigationPath`) pour pouvoir l'inspecter dans les tests.
    @Published var path: [AppRoute] = []

    /// Closure injectée : permet au coordinateur de connaître le nom de catégorie
    /// sans dépendre du ViewModel.
    private let categoryName: (Listing) -> String

    init(categoryName: @escaping (Listing) -> String) {
        self.categoryName = categoryName
    }

    // MARK: - Intentions (ce que les vues appellent)

    /// Affiche l'écran des favoris.
    func showFavorites() {
        push(.favorites)
    }

    // MARK: - Fabrique des écrans

    /// Construit la vue associée à une route.
    @ViewBuilder
    func view(for route: AppRoute) -> some View {
        switch route {
        case .details(let listing):
            ListingDetailsView(listing: listing, categoryName: categoryName(listing))
        case .favorites:
            FavoritesView(categoryName: categoryName)
        }
    }

    // MARK: - Privé

    private func push(_ route: AppRoute) {
        // Un double toucher ne doit pas empiler deux fois le même écran.
        guard path.last != route else { return }
        path.append(route)
    }
}
