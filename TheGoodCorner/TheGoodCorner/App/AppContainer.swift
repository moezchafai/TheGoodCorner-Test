//
//  AppContainer.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import Foundation

struct AppContainer {
    let repository: ListingRepository

    static func live() -> AppContainer {
        let baseURL = URL(string: "http://localhost:8080")!
        let api = ListingAPIClient(httpClient: URLSessionHTTPClient(), baseURL: baseURL)
        return AppContainer(repository: ListingRepositoryImpl(api: api, baseURL: baseURL))
    }

    func makeListingListViewModel() -> ListingListViewModel {
        ListingListViewModel(repository: repository)
    }
}
