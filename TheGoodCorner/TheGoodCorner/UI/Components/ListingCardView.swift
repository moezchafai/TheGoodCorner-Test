//
//  ListingCardView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 13/10/2026.
//

import Foundation
import SwiftUI

struct ListingCardView: View {

    let listing: Listing
    let categoryName: String
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = DesignTokens.Size.thumbnailDefault

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.cardPadding) {

            ZStack(alignment: .topTrailing) {
                ListingImageView(url: listing.thumbImageURL ?? listing.smallImageURL)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.thumbnail, style: .continuous))

                FavoriteButton(
                    isFavorite: isFavorite,
                    variant: .onImage,
                    action: onToggleFavorite
                )
                .padding(6)
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.contentSpacing) {

                if !categoryName.isEmpty {
                    Text(categoryName.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
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

                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.blockSpacing) {
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
        .padding(DesignTokens.Spacing.cardPadding)
        .floatingCardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .favoriteAccessibilityAction(isFavorite: isFavorite, toggle: onToggleFavorite)
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if listing.isUrgent { parts.append("Annonce urgente") }
        parts.append(contentsOf: [listing.title, categoryName, listing.priceText])
        if isFavorite { parts.append("Dans vos favoris") }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
