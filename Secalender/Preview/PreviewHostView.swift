//  PreviewHostView.swift
//  Secalender
//
//  Created by ChatGPT on 2025/6/10.
//

import SwiftUI

struct PreviewHostView<Content: View>: View {
    let content: () -> Content
    var body: some View {
        content()
            .environmentObject(MockFirebaseUserManager.shared)
    }
}
