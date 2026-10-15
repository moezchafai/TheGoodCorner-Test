//
//  ListingDetailsView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//


import SwiftUI

struct ListingDetailsView: View {

    @EnvironmentObject private var favorites: FavoritesViewModel

    @State private var showContactAlert = false

    let listing: Listing
    let categoryName: String

    var body: some View {
        ZStack(alignment: .bottom) {

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // MARK: - Image
                    ListingImageView(
                        url: listing.smallImageURL ?? listing.thumbImageURL,
                        accessibilityLabel: "Photo de l'annonce : \(listing.title)"
                    )
                    .frame(height: 280)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if listing.isUrgent {
                        UrgentBadge()
                    }

                    // MARK: - Titre & Prix
                    VStack(alignment: .leading, spacing: 6) {
                        Text(listing.title)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .accessibilityAddTraits(.isHeader)

                        Text(listing.priceText)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundColor(Color.brandBlueDark)
                            .accessibilityLabel("Prix : \(listing.priceText)")
                    }

                    // MARK: - Métadonnées (Catégorie & Date)
                    VStack(alignment: .leading, spacing: 6) {
                        Label(categoryName, systemImage: "tag")
                        Label("Publiée le \(listing.dateText)", systemImage: "calendar")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Divider()

                    // MARK: - Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .accessibilityAddTraits(.isHeader)

                        Text(listing.description.isEmpty
                             ? "Aucune description fournie pour cette annonce."
                             : listing.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                }
                .padding(20)
                .padding(.bottom, 90) // pour ne pas être caché par le bouton flottant
            }

            // MARK: - Bouton d'action flottant
            VStack {
                Button {
                    showContactAlert = true
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Contacter le vendeur")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandOrange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .accessibilityLabel("Contacter le vendeur")
                .accessibilityHint("Ouvre une alerte pour contacter le vendeur")
            }
        }
        .navigationTitle("Détail de l'annonce")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                let isFavorite = favorites.isFavorite(listing)
                Button {
                    favorites.toggle(listing)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? Color.red : Color.primary)
                }
                .accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
            }
        }
        .alert("Contacter le vendeur", isPresented: $showContactAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("La messagerie sera bientôt disponible dans l'application.")
        }
    }
}
