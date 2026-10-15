//
//  AppCoordinatorView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 15/10/2026.
//

import Foundation
import SwiftUI

/// Racine de la navigation : possède le NavigationStack et déclare, une seule fois,
/// comment chaque route devient un écran.
struct AppCoordinatorView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var listViewModel: ListingListViewModel

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ListingListView(viewModel: listViewModel)
                .navigationDestination(for: AppRoute.self) { route in
                    coordinator.view(for: route)
                }
        }
        // Posé en dehors du stack : disponible dans tous les écrans empilés.
        .tint(Color.brandBlueDark)
        .environmentObject(coordinator)
    }
}
