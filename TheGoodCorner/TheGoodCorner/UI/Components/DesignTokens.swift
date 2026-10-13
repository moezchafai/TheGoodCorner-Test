//
//  DesignTokens.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
import SwiftUI

/// Constantes de design centralisées : rayons, espacements, ombres, tailles.
enum DesignTokens {

    // MARK: - Corner Radius

    enum Radius {
        /// Rayon des cartes d'annonces (floating cards).
        static let card: CGFloat = 16
        /// Rayon des vignettes d'image.
        static let thumbnail: CGFloat = 12
        /// Rayon des chips de catégories.
        static let chip: CGFloat = 20
        /// Rayon des badges (URGENT, etc.).
        static let badge: CGFloat = 6
    }

    // MARK: - Spacing

    enum Spacing {
        /// Espace interne d'une carte (padding autour du contenu).
        static let cardPadding: CGFloat = 12
        /// Espace entre deux cartes dans la liste.
        static let listSpacing: CGFloat = 12
        /// Espace entre les éléments d'une carte (lignes de texte).
        static let contentSpacing: CGFloat = 4
        /// Espace entre les blocs (ex : catégorie et titre).
        static let blockSpacing: CGFloat = 8
    }

    // MARK: - Shadow (light mode)

    enum Shadow {
        static let color = Color.black.opacity(0.06)
        static let radius: CGFloat = 8
        static let yOffset: CGFloat = 2
    }

    // MARK: - Sizes

    enum Size {
        /// Taille par défaut de la vignette (scalée via @ScaledMetric dans la vue).
        static let thumbnailDefault: CGFloat = 96
    }
}

// MARK: - Card modifier

extension View {
    /// Applique le style "carte flottante" : fond, coins arrondis, ombre douce.
    func floatingCardStyle() -> some View {
        self
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
            .shadow(
                color: DesignTokens.Shadow.color,
                radius: DesignTokens.Shadow.radius,
                x: 0,
                y: DesignTokens.Shadow.yOffset
            )
    }
}
