//
//  APIConfiguration.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 15/10/2026.
//

import Foundation

/// Configuration réseau de l'app : la seule source de l'adresse du serveur.
enum APIConfiguration {
    /// Serveur local fourni avec le test (`cd server && swift run`).
    static let baseURL = URL(string: "http://localhost:8080")!
}
