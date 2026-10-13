//
//  TheGoodCornerApp.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//


import SwiftUI

@main
struct TheGoodCornerApp: App {
    private let container: AppContainer

    /// Une seule instance, partagée par la liste, le détail et l'écran des favoris.
    @StateObject private var favorites: FavoritesViewModel

    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    init() {
        let container = AppContainer.live()
        self.container = container
        _favorites = StateObject(wrappedValue: container.makeFavoritesViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ListingListView(viewModel: container.makeListingListViewModel())
                .environmentObject(favorites)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        }
    }
}
