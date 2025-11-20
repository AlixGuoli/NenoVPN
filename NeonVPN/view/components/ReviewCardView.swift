//
//  ReviewCardView.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/20.
//

import SwiftUI
import UIKit

struct ReviewCardView: View {
    @State private var selectedRating: Int = 4
    @State private var wave = false
    @State private var shimmerOffset: CGFloat = -1.2
    
    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            VStack(alignment: .center, spacing: 8) {
                Text(LocalizedText("ReviewCard_Title"))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(LocalizedText("ReviewCard_Description"))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        selectedRating = index
                        openReviewPage()
                    } label: {
                        let isActive = index <= selectedRating
                        Image(systemName: isActive ? "star.fill" : "star")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(isActive ? Color.yellow : Color.white.opacity(0.45))
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(isActive ? Color.yellow.opacity(0.12) : Color.white.opacity(0.08))
                            )
                            .scaleEffect(isActive ? (wave ? 1.08 : 0.96) : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index - 1) * 0.08),
                                value: wave
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.6), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onTapGesture {
            openReviewPage()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                wave.toggle()
            }
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.2
            }
        }
    }
    
    private func openReviewPage() {
        let reviewURL = "https://apps.apple.com/app/id6753937623?action=write-review"
        if let url = URL(string: reviewURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

