//
//  ListingDTO.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation

struct ListingDTO: Decodable {

    struct ImagesURL: Decodable {
        let small: String?
        let thumb: String?
    }

    let id: Int
    let title: String
    let description: String?
    let price: Double
    let categoryId: Int        // JSON : "category_id"
    let isUrgent: Bool         // JSON : "is_urgent"
    let creationDate: Date     // JSON : "creation_date" (ISO 8601)
    let imagesUrl: ImagesURL?  // JSON : "images_url"
}

// MARK: - Mapping vers le Domain

extension ListingDTO {

    func toDomain(baseURL: URL) -> Listing {
        Listing(
            id: id,
            title: title,
            description: description ?? "",
            price: price,
            categoryID: categoryId,
            isUrgent: isUrgent,
            creationDate: creationDate,
            smallImageURL: Self.resolve(imagesUrl?.small, baseURL: baseURL),
            thumbImageURL: Self.resolve(imagesUrl?.thumb, baseURL: baseURL)
        )
    }

    /// Transforme "/images/ad-small/x.jpg" en "http://localhost:8080/images/ad-small/x.jpg".
    /// Retourne nil si le chemin est absent ou vide.
    private static func resolve(_ path: String?, baseURL: URL) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }
}
