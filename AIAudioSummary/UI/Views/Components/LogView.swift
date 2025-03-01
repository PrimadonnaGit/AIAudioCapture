//
//  LogView.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI

struct LogView: View {
    let logMessages: [LogMessage]
    let theme: SolarizedTheme
    let onClear: () -> Void

    private var logDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("활동 로그")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.brightText)

                Spacer()

                Text("\(logMessages.count)개 항목")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(theme.dimText)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(logMessages) { message in
                        HStack(alignment: .top, spacing: 10) {
                            // 타임스탬프
                            Text(message.timestamp, formatter: logDateFormatter)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.dimText)

                            // 메시지 내용
                            Text(message.text)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(getLogTextColor(message: message.text))
                                .lineLimit(3)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.secondaryBg.opacity(0.4))
                        )
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
            }
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.background.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.secondaryBg.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBg)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        )
    }

    // 로그 메시지 색상 선택
    private func getLogTextColor(message: String) -> Color {
        if message.contains("⚠️") {
            return theme.warning.opacity(0.95)
        } else if message.contains("오류") || message.contains("실패") {
            return theme.danger.opacity(0.95)
        } else if message.contains("✅") || message.contains("성공") {
            return theme.success.opacity(0.95)
        } else if message.contains("BlackHole") {
            return theme.highlight.opacity(0.95)
        } else {
            return theme.foreground.opacity(0.95)
        }
    }
}
