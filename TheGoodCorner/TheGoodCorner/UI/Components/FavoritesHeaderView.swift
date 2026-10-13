//
//  FavoritesHeaderView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
import SwiftUI

/// En-tête de l'écran Favoris : titre, badge de compteur, sous-titre.
struct FavoritesHeaderView: View {

    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.blockSpacing) {

            HStack(alignment: .firstTextBaseline) {
                Text("Mes Favoris")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Spacer()

                if count > 0 {
                    countBadge
                }
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mes Favoris, \(countLabel)")
    }

    // MARK: - Private

    private var countBadge: some View {
        Text(countLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brandBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brandBlueLight, in: Capsule())
    }

    private var countLabel: String {
        count == 1 ? "1 annonce" : "\(count) annonces"
    }

    private var subtitle: String {
        count == 0
            ? "Ajoutez des annonces en touchant le cœur pour les retrouver ici."
            : "Retrouvez les annonces que vous suivez pour ne rien manquer."
    }
}

#Preview {
    VStack(spacing: 20) {
        FavoritesHeaderView(count: 3)
        FavoritesHeaderView(count: 1)
        FavoritesHeaderView(count: 0)
    }
    .padding(.vertical)
    .background(Color.screenBackground)
}
