//
//  CategoryDTO.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation

struct CategoryDTO: Decodable {
    let id: Int
    let name: String
}

// MARK: - Mapping vers le Domain

extension CategoryDTO {
    func toDomain() -> ListingCategory {
        ListingCategory(id: id, name: name)
    }
}
