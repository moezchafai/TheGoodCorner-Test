//
//  TheGoodCornerApp.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import SwiftUI

@main
struct TheGoodCornerApp: App {
    private let container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            ListingListView(viewModel: container.makeListingListViewModel())
        }
    }
}
