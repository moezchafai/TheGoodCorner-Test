//
//  MockFavoritesRepository.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation

@testable import TheGoodCorner

final class MockFavoritesRepository: FavoritesRepository {

    /// Ce qui est « sur le disque ».
    var stored: [Listing]
    private(set) var saveCallCount = 0

    init(stored: [Listing] = []) {
        self.stored = stored
    }

    func loadFavorites() -> [Listing] { stored }

    func saveFavorites(_ listings: [Listing]) {
        stored = listings
        saveCallCount += 1
    }
}
