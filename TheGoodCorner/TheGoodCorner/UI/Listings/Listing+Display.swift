//
//  Listing+Display.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation

extension Listing {
    // Prix formaté en euros (ex: "10,00 €").
    var priceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: price)) ?? "\(price) €"
    }

    // Date de publication formatée en français (ex: "6 novembre 2019 à 12:21").
    var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy 'à' HH:mm"
        return formatter.string(from: creationDate)
    }

    // Description d'accessibilité pour VoiceOver.
    var accessibilityDescription: String {
        var description = "\(title), \(priceText)"
        if isUrgent {
            description += ", annonce urgente"
        }
        return description
    }
}
