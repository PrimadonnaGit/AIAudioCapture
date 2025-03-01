//
//  SolarizedTheme.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI

// 부드러운 Solarized Dark 테마 색상 구조체
enum SolarizedColors {
    // 앱 설정을 참조하여 색상 불러오기
    static func themeWith(settings: AppSettings) -> SolarizedTheme {
        return SolarizedTheme(settings: settings)
    }

    // 기본 색상 값 (설정 참조 없음)
    static let base03 = Color(hex: "002b36") // 기본 배경
    static let base02 = Color(hex: "073642") // 컨트롤 배경
    static let base01 = Color(hex: "586e75") // 흐린 텍스트
    static let base00 = Color(hex: "657b83") // 중간 텍스트
    static let base0 = Color(hex: "839496") // 기본 텍스트
    static let base1 = Color(hex: "93a1a1") // 밝은 텍스트
    static let base2 = Color(hex: "eee8d5").opacity(0.1) // 강조 배경
    static let base3 = Color(hex: "fdf6e3").opacity(0.05) // 가장 밝은 배경

    static let yellow = Color(hex: "b58900") // 노란색 강조
    static let orange = Color(hex: "cb4b16") // 경고색 (주황)
    static let red = Color(hex: "dc322f") // 주의색 (빨강)
    static let magenta = Color(hex: "d33682") // 자주색
    static let violet = Color(hex: "6c71c4") // 보라색
    static let blue = Color(hex: "268bd2") // 파랑색
    static let cyan = Color(hex: "2aa198") // 청록색
    static let green = Color(hex: "859900") // 녹색
}

// 앱 설정에 따라 변경되는 테마 구조체
struct SolarizedTheme {
    let settings: AppSettings

    // 배경 색상
    var background: Color {
        return SolarizedColors.base03.opacity(settings.backgroundOpacity)
    }

    var secondaryBg: Color {
        return SolarizedColors.base02.opacity(settings.uiOpacity)
    }

    var foreground: Color {
        return SolarizedColors.base0.opacity(min(settings.uiOpacity + 0.1, 1.0))
    }

    // 설정에서 선택한 액센트 색상
    var highlight: Color {
        return settings.currentAccentColor.opacity(settings.uiOpacity)
    }

    var warning: Color {
        return SolarizedColors.orange.opacity(settings.uiOpacity + 0.05)
    }

    var danger: Color {
        return SolarizedColors.red.opacity(settings.uiOpacity + 0.05)
    }

    var success: Color {
        return SolarizedColors.green.opacity(settings.uiOpacity)
    }

    var accent: Color {
        return SolarizedColors.blue.opacity(settings.uiOpacity)
    }

    var yellow: Color {
        return SolarizedColors.yellow.opacity(settings.uiOpacity)
    }

    var purple: Color {
        return SolarizedColors.violet.opacity(settings.uiOpacity - 0.05)
    }

    var magenta: Color {
        return SolarizedColors.magenta.opacity(settings.uiOpacity - 0.05)
    }

    var brightText: Color {
        return SolarizedColors.base1.opacity(min(settings.uiOpacity + 0.1, 1.0))
    }

    var dimText: Color {
        return SolarizedColors.base01.opacity(settings.uiOpacity)
    }

    var cardBg: Color {
        return SolarizedColors.base02.opacity(settings.uiOpacity - 0.15)
    }

    // 버튼 배경용 gradient
    func buttonGradient(_ color: Color) -> LinearGradient {
        let baseOpacity = settings.uiOpacity
        return LinearGradient(
            gradient: Gradient(colors: [
                color.opacity(baseOpacity),
                color.opacity(baseOpacity - 0.1),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // 배경 그라데이션
    var backgroundGradient: LinearGradient {
        return LinearGradient(
            gradient: Gradient(colors: [
                background,
                Color(hex: "00252e").opacity(settings.backgroundOpacity - 0.05),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
