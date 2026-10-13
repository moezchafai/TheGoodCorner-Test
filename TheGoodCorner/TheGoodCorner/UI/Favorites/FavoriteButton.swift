//
//  FavoriteButton.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
import SwiftUI

/// Cœur à poser sur une image. La zone de toucher fait 44 pt (minimum recommandé),
/// même si le disque visible est plus petit.
struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isFavorite ? Color.red : Color.primary)
                .padding(7)
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        // `.borderless` : dans une liste, le toucher du cœur ne doit pas ouvrir la ligne.
        .buttonStyle(.borderless)
        .animation(.easeInOut(duration: 0.15), value: isFavorite)
        .accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
    }
}

extension View {
    /// Pour VoiceOver : le cœur d'une ligne n'est pas atteignable seul (la ligne est lue en un bloc),
    /// on l'expose donc comme une action de la ligne (balayer vers le haut ou le bas).
    func favoriteAccessibilityAction(isFavorite: Bool, toggle: @escaping () -> Void) -> some View {
        accessibilityAction(named: isFavorite ? "Retirer des favoris" : "Ajouter aux favoris", toggle)
    }
}
