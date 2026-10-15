//
//  UrgentBadge.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import SwiftUI




/// Badge "URGENT" affiché sur les annonces marquées comme urgentes.
/// Suit le Dynamic Type grâce aux styles de texte système.
struct UrgentBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.caption2.weight(.bold))
            Text("URGENT")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Annonce urgente")
    }
}

#Preview {
    VStack(spacing: 12) {
        UrgentBadge()
        UrgentBadge().environment(\.sizeCategory, .accessibilityExtraLarge)
    }
    .padding()
}
