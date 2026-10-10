//
//  Listing.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation

struct Listing: Identifiable, Equatable {
    let id: Int
    let title: String
    let price: Double
    let categoryId: Int
    let description: String
    let isUrgent: Bool
    let imageSmallURL: URL?
    let imageThumbURL: URL?
}
