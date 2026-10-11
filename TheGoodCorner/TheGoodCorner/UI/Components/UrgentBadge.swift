//
//  UrgentBadge.swift
//  TheGoodCorner
//
//  Created by Moez bachagha on 11/10/2026.
//

import Foundation
import SwiftUI

struct UrgentBadge: View {
    var body: some View {
        Label("Urgent", systemImage: "bolt.fill")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(Color.red)
            .background(Color.red.opacity(0.12))
            .clipShape(Capsule())
    }
}
