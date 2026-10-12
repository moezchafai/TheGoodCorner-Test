//
//  ListingRepository.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation
import Combine

protocol ListingRepository {
    // `query` : texte de recherche envoyé au serveur (nil = toutes les annonces).
    func fetchListings(query: String?) -> AnyPublisher<[Listing], Error>
    func fetchCategories() -> AnyPublisher<[ListingCategory], Error>
}

extension ListingRepository {
    func fetchListings() -> AnyPublisher<[Listing], Error> {
        fetchListings(query: nil)
    }
}
