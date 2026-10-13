//
//  CategoryFilterView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.


import SwiftUI

struct CategoryFilterView: View {
    let categories: [ListingCategory]
    let allCountText: String
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
            Text(count.map { "\(name) \($0)" } ?? name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? AnyShapeStyle(Color.brandBlue)
                    : AnyShapeStyle(Color.cardBackground)
                )
                .foregroundStyle(isSelected ? Color.white : Color.brandBlueDark)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected ? Color.brandBlue.opacity(0.25) : Color.clear,
                    radius: 4,
                    y: 2
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(name: name, count: count))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityText(name: String, count: String?) -> String {
        guard let count else { return name }
        if count.hasSuffix("+") {
            return "\(name), au moins \(count.dropLast()) annonces"
        }
        let plural = (Int(count) ?? 2) > 1 ? "s" : ""
        return "\(name), \(count) annonce\(plural)"
    }
}
