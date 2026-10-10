//
//  NetworkError.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 10/10/2026.
//

import Foundation


enum NetworkError: LocalizedError, Equatable {
    /// L'URL construite est invalide.
    case invalidURL

    /// La réponse reçue n'est pas une `HTTPURLResponse` valide.
    case invalidResponse

    /// Le serveur a renvoyé un code HTTP d'erreur (hors 2xx).
    case badStatus(Int)

    /// Le décodage du JSON a échoué.
    case decodingFailed

    /// Erreur de transport (pas de connexion, timeout, etc.).
    case transport

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "L'URL de la requête est invalide."
        case .invalidResponse:
            return "La réponse du serveur est invalide."
        case .badStatus(let code):
            return "Erreur serveur (code \(code))."
        case .decodingFailed:
            return "Impossible de lire les données reçues."
        case .transport:
            return "Problème de connexion. Vérifiez votre réseau."
        }
    }
}
