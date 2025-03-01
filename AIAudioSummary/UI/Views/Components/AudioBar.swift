//
//  AudioBar.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI

// 오디오 바 애니메이션 뷰
struct AudioBar: View {
    let index: Int
    let level: Float
    let isRecording: Bool
    let theme: SolarizedTheme
    
    var body: some View {
        let barHeight = calculateHeight()
        
        RoundedRectangle(cornerRadius: 3)
            .fill(barColor)
            .frame(width: 4, height: barHeight)
            .animation(.easeOut(duration: 0.2), value: level)
    }
    
    private func calculateHeight() -> CGFloat {
        if !isRecording {
            return 5
        }
        
        // 인덱스에 따라 다른 높이 생성 (더 자연스러운 파형을 위해)
        let seed = sin(Double(index) * 0.8) * 0.5 + 0.5
        let variation = sin(Date().timeIntervalSince1970 * 3 + Double(index)) * 0.3 + 0.7
        
        let height = CGFloat(level * Float(seed) * Float(variation) * 80) + 5
        return max(height, 5)
    }
    
    private var barColor: Color {
        if !isRecording {
            return theme.secondaryBg.opacity(0.6)
        }
        
        // 레벨에 따른 색상 변화 (더 부드러운 색상)
        if level < 0.3 {
            return theme.highlight.opacity(0.6 + Double(level))
        } else if level < 0.7 {
            return theme.accent.opacity(0.7)
        } else {
            return theme.warning.opacity(0.7)
        }
    }
}
