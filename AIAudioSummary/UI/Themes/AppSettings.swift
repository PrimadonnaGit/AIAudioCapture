//
//  AppSettings.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI

// 앱 설정을 관리하는 클래스
class AppSettings: ObservableObject {
    @Published var uiOpacity: Double {
        didSet {
            UserDefaults.standard.set(uiOpacity, forKey: "uiOpacity")
        }
    }
    
    @Published var backgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity")
        }
    }
    
    @Published var accentColorIndex: Int {
        didSet {
            UserDefaults.standard.set(accentColorIndex, forKey: "accentColorIndex")
        }
    }
    
    // 액센트 색상 옵션
    let accentColorOptions = [
        ("청록", Color(hex: "2aa198")),  // 기본 Solarized 청록
        ("파랑", Color(hex: "268bd2")),  // Solarized 파랑
        ("녹색", Color(hex: "859900")),  // Solarized 녹색
        ("보라", Color(hex: "6c71c4")),  // Solarized 보라
        ("자주", Color(hex: "d33682")),  // Solarized 자주
        ("노랑", Color(hex: "b58900"))   // Solarized 노랑
    ]
    
    var currentAccentColor: Color {
        return accentColorOptions[accentColorIndex].1
    }
    
    init() {
        // 저장된 설정 로드 또는 기본값 사용
        self.uiOpacity = UserDefaults.standard.object(forKey: "uiOpacity") as? Double ?? 0.85
        self.backgroundOpacity = UserDefaults.standard.object(forKey: "backgroundOpacity") as? Double ?? 0.95
        self.accentColorIndex = UserDefaults.standard.object(forKey: "accentColorIndex") as? Int ?? 0
    }
    
    // 모든 설정을 기본값으로 재설정
    func resetToDefaults() {
        uiOpacity = 0.85
        backgroundOpacity = 0.95
        accentColorIndex = 0
    }
}
