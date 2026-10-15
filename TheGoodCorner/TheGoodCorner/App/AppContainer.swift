//
//  AppContainer.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation

struct AppContainer {
    let repository: ListingRepository
    let favoritesRepository: FavoritesRepository

    static func live(baseURL: URL = APIConfiguration.baseURL) -> AppContainer {
        let api = ListingAPIClient(httpClient: URLSessionHTTPClient(), baseURL: baseURL)
        return AppContainer(repository: ListingRepositoryImpl(api: api, baseURL: baseURL),
                            favoritesRepository: UserDefaultsFavoritesStore())
    }
    func makeListingListViewModel() -> ListingListViewModel {
        ListingListViewModel(repository: repository)
    }

    func makeFavoritesViewModel() -> FavoritesViewModel {
        FavoritesViewModel(repository: favoritesRepository)
    }
}
