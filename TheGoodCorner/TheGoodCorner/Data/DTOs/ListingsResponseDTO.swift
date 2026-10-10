//
//  ListingsResponseDTO.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation

struct ListingsResponseDTO: Decodable {
    let items: [ListingDTO]
    let total: Int
    let page: Int
    let limit: Int
    let hasMore: Bool   // JSON : "has_more"
}
