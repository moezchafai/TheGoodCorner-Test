//
//  FavoriteButton.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//


import Foundation
import SwiftUI

/// Cœur à poser sur une image. La zone de toucher fait 44 pt.
struct FavoriteButton: View {

    enum Variant {
        /// Sur une image (cœur blanc par défaut, glassmorphism).
        case onImage
        /// Sur un fond clair (cœur primaire par défaut).
        case onSurface
    }

    let isFavorite: Bool
    var variant: Variant = .onSurface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(foregroundColor)
                .padding(7)
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .animation(.easeInOut(duration: 0.15), value: isFavorite)
        .accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
    }

    // MARK: - Private

    private var foregroundColor: Color {
        if isFavorite { return .red }
        switch variant {
        case .onImage:    return .white
        case .onSurface:  return .primary
        }
    }
}

extension View {
    /// Pour VoiceOver : expose le toggle favori comme action de la ligne.
    func favoriteAccessibilityAction(isFavorite: Bool, toggle: @escaping () -> Void) -> some View {
        accessibilityAction(named: isFavorite ? "Retirer des favoris" : "Ajouter aux favoris", toggle)
    }
}
