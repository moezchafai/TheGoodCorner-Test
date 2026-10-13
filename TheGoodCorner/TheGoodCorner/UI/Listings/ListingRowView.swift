//
//  ListingRowView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.


import SwiftUI

struct ListingRowView: View {
    let listing: Listing
    let categoryName: String
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    @ScaledMetric(relativeTo: .body) private var imageSize: CGFloat = 88

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // MARK: - Vignette de l'annonce
            ListingImageView(url: listing.thumbImageURL ?? listing.smallImageURL)
                .frame(width: imageSize, height: imageSize)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
        // Masqué à VoiceOver : la ligne est lue en un bloc, le cœur est une action de la ligne.
                    FavoriteButton(isFavorite: isFavorite, action: onToggleFavorite)
                        .accessibilityHidden(true)
                }

            // MARK: - Informations textuelles
            VStack(alignment: .leading, spacing: 4) {
                if !categoryName.isEmpty {
                    Text(categoryName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(listing.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 2)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(listing.priceText)
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.brandBlueDark)

                    if listing.isUrgent {
                        UrgentBadge()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Accessibilité

    private var accessibilityText: String {
        var parts: [String] = []
        if listing.isUrgent { parts.append("Annonce urgente") }
        parts.append(contentsOf: [listing.title, categoryName, listing.priceText])
        if isFavorite { parts.append("Dans vos favoris") }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
