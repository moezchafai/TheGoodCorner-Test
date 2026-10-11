//
//  Color+Theme.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import SwiftUI

extension Color {

    // MARK: - Brand

    // Orange principal
    static let brandOrange = Color(red: 1.0, green: 0.43, blue: 0.08)   // #FF6E14

    // Bleu secondaire (complémentaire de l'orange).
    static let brandBlue = Color(red: 0.0, green: 0.48, blue: 0.78)     // #007AC7

    // Variante claire du bleu (fonds, chips non sélectionnés).
    static let brandBlueLight = Color(red: 0.0, green: 0.48, blue: 0.78).opacity(0.12)

    // Variante foncée du bleu (hover, textes importants).
    static let brandBlueDark = Color(red: 0.0, green: 0.35, blue: 0.60) // #005999

    // MARK: - Semantic

    // Fond des écrans.
    static let screenBackground = Color(uiColor: .systemGroupedBackground)

    // Fond des cartes.
    static let cardBackground = Color(uiColor: .systemBackground)

    // Fond des filtres non sélectionnés.
    static let chipBackground = Color.gray.opacity(0.15)

    // MARK: - Urgent

    // Fond du badge URGENT.
    static let urgentBackground = Color.orange.opacity(0.15)

    // Texte du badge URGENT.
    static let urgentForeground = Color.orange
}
