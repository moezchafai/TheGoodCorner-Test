//
//  Listing+Display.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation

extension Listing {
    var priceText: String {
        price.formatted(
            .currency(code: "EUR")
            .precision(.fractionLength(0))
            .locale(Locale(identifier: "fr_FR"))
        )
    }

    var dateText: String {
        creationDate.formatted(date: .abbreviated, time: .shortened)
    }
}
