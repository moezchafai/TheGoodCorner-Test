//
//  AppearanceMode.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 12/10/2026.
//

import Foundation
import SwiftUI

/// Réglage d'apparence choisi par l'utilisateur.
/// `system` suit le réglage de l'appareil (valeur par défaut).
enum AppearanceMode: String {
    case system, light, dark

    /// `nil` = ne rien imposer, SwiftUI suit le système.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    static let storageKey = "appearanceMode"
}
