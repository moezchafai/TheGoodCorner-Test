//
//  Fixtures.swift
//  TheGoodCornerTests
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
enum Fixtures {

    // Deux annonces : la 2e n'a ni description, ni images (images_url vide).
    static let listingsJSON = """
    {
      "page": 1, "has_more": false, "total": 2, "limit": 2,
      "items": [
        {
          "is_urgent": true, "id": 1, "creation_date": "2019-11-06T11:22:35Z",
          "title": "Vinyle", "price": 10, "category_id": 7, "description": "Bon état",
          "images_url": { "small": "/images/ad-small/a.jpg", "thumb": "/images/ad-thumb/a.jpg" }
        },
        {
          "is_urgent": false, "id": 2, "creation_date": "2019-11-05T20:04:38Z",
          "title": "Pull", "price": 10, "category_id": 2,
          "images_url": {}
        }
      ]
    }
    """

    static let categoriesJSON = """
    [ { "id": 1, "name": "Véhicule" }, { "id": 2, "name": "Mode" } ]
    """
}
