//
//  SettingsView.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var showingSettings: Bool
    var theme: SolarizedTheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 헤더
                Text("설정")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(theme.highlight)
                    .padding(.top, 24)
                
                // 설정 섹션들
                VStack(spacing: 24) {
                    // UI 색상 섹션
                    settingSection(title: "UI 색상") {
                        // 액센트 색상 선택
                        VStack(alignment: .leading, spacing: 10) {
                            Text("액센트 색상")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(theme.foreground)
                            
                            HStack(spacing: 12) {
                                ForEach(0..<settings.accentColorOptions.count, id: \.self) { index in
                                    let (name, color) = settings.accentColorOptions[index]
                                    
                                    Button(action: {
                                        withAnimation {
                                            settings.accentColorIndex = index
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 36, height: 36)
                                            
                                            if settings.accentColorIndex == index {
                                                Circle()
                                                    .strokeBorder(Color.white, lineWidth: 2)
                                                    .frame(width: 36, height: 36)
                                            }
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .overlay(
                                        Text(name)
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.dimText)
                                            .padding(.top, 40)
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.bottom, 8)
                        
                        // UI 투명도 슬라이더
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("UI 투명도")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.foreground)
                                
                                Spacer()
                                
                                Text("\(Int(settings.uiOpacity * 100))%")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.dimText)
                            }
                            
                            HStack {
                                Text("투명")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.dimText)
                                
                                Slider(value: $settings.uiOpacity, in: 0.5...1.0, step: 0.01)
                                    .accentColor(theme.highlight)
                                
                                Text("불투명")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.dimText)
                            }
                        }
                        
                        // 배경 투명도 슬라이더
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("배경 투명도")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.foreground)
                                
                                Spacer()
                                
                                Text("\(Int(settings.backgroundOpacity * 100))%")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.dimText)
                            }
                            
                            HStack {
                                Text("투명")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.dimText)
                                
                                Slider(value: $settings.backgroundOpacity, in: 0.7...1.0, step: 0.01)
                                    .accentColor(theme.highlight)
                                
                                Text("불투명")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.dimText)
                            }
                        }
                    }
                    
                    // 미리보기 섹션
                    settingSection(title: "미리보기") {
                        // 미리보기 카드
                        HStack(spacing: 16) {
                            // 원형 인디케이터
                            Circle()
                                .fill(theme.highlight)
                                .frame(width: 16, height: 16)
                            
                            // 텍스트
                            VStack(alignment: .leading, spacing: 4) {
                                Text("설정 미리보기")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.brightText)
                                
                                Text("현재 설정된 테마 스타일입니다")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.foreground)
                            }
                            
                            Spacer()
                            
                            // 버튼 샘플
                            Button(action: {}) {
                                Text("버튼")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.background)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .fill(theme.buttonGradient(theme.highlight))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.cardBg)
                        )
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                
                Divider()
                    .background(theme.dimText.opacity(0.2))
                    .padding(.vertical, 8)
                
                // 하단 버튼들
                HStack(spacing: 16) {
                    // 기본값으로 재설정 버튼
                    Button(action: {
                        settings.resetToDefaults()
                    }) {
                        Text("기본값으로 재설정")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(theme.dimText)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                Capsule()
                                    .stroke(theme.dimText.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 확인 버튼
                    Button(action: {
                        showingSettings = false
                    }) {
                        Text("확인")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(theme.background)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 24)
                            .background(
                                Capsule()
                                    .fill(theme.buttonGradient(theme.highlight))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 24)
            }
            .background(
                ZStack {
                    theme.backgroundGradient
                    
                    // 미묘한 노이즈 패턴 오버레이
                    Rectangle()
                        .fill(Color.black.opacity(0.02))
                }
            )
        }
    }
    
    // 설정 섹션 헬퍼 함수
    private func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(theme.highlight)
            
            content()
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.secondaryBg)
                )
        }
    }
}
