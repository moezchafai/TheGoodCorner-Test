//
//  TheGoodCornerApp.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//


import SwiftUI

@main
struct TheGoodCornerApp: App {

    // MARK: - Dependencies

    private let container: AppContainer

    // MARK: - Shared state (owned by the App)

    @StateObject private var favorites: FavoritesViewModel
    @StateObject private var listViewModel: ListingListViewModel
    @StateObject private var coordinator: AppCoordinator

    // MARK: - Appearance

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    // MARK: - Init

    init() {
        let container = AppContainer.live()
        self.container = container

        // On crée le ViewModel une seule fois (sinon SwiftUI le recrée à chaque redraw).
        let listViewModel = container.makeListingListViewModel()

        _favorites = StateObject(wrappedValue: container.makeFavoritesViewModel())
        _listViewModel = StateObject(wrappedValue: listViewModel)

        // Le coordinateur a besoin du nom des catégories : le ViewModel le connaît.
        _coordinator = StateObject(wrappedValue: AppCoordinator(
            categoryName: { listing in listViewModel.categoryName(for: listing) }
        ))
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: coordinator, listViewModel: listViewModel)
                .environmentObject(favorites)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        }
    }
}
