//
//  ListingRepository.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation
import Combine

protocol ListingRepository {
    func fetchListings() -> AnyPublisher<[Listing], Error>
    func fetchCategories() -> AnyPublisher<[ListingCategory], Error>
}
