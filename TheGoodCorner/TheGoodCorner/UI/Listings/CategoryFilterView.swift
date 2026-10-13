//
//  CategoryFilterView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.


import SwiftUI

struct CategoryFilterView: View {
    let categories: [ListingCategory]

    /// Compteur de « Toutes » : exact dès la première page (le total vient du serveur).
    let allCountText: String

    /// Compteur d'une catégorie : « 12+ » tant qu'il reste des pages, « 47 » une fois tout chargé,
    /// nil quand on ne sait rien (le serveur ne compte pas par catégorie).
    let countText: (ListingCategory) -> String?

    @Binding var selection: ListingCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Toutes", count: allCountText, isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(categories) { category in
                    chip(category.name, count: countText(category), isSelected: selection == category) {
                        selection = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ name: String,
                      count: String?,
                      isSelected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(count.map { "\(name) (\($0))" } ?? name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(name: name, count: count))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// VoiceOver lit une phrase, pas « Mode parenthèse douze plus » :
    /// « Mode, au moins 12 annonces » ou « Mode, 47 annonces ».
    private func accessibilityText(name: String, count: String?) -> String {
        guard let count else { return name }
        if count.hasSuffix("+") {
            return "\(name), au moins \(count.dropLast()) annonces"
        }
        let plural = (Int(count) ?? 2) > 1 ? "s" : ""
        return "\(name), \(count) annonce\(plural)"
    }
}
