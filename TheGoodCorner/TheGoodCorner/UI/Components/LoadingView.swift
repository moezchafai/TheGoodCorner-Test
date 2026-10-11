//
//  LoadingView.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView("Chargement des annonces…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
