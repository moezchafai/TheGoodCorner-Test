//
//  Listing.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation


struct Listing: Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let categoryID: Int
    let isUrgent: Bool
    let creationDate: Date
    let smallImageURL: URL?
    let thumbImageURL: URL?
}
