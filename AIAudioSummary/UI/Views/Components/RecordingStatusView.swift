//
//  RecordingStatusView.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI

struct RecordingStatusView: View {
    @ObservedObject var audioCaptureManager: AudioCaptureManager
    let theme: SolarizedTheme
    let recordingTime: TimeInterval
    @Binding var animateWave: Bool

    var body: some View {
        HStack(spacing: 16) {
            // 상태 표시기
            ZStack {
                Circle()
                    .fill(audioCaptureManager.isRecording ? theme.danger : theme.secondaryBg)
                    .frame(width: 16, height: 16)

                if audioCaptureManager.isRecording {
                    Circle()
                        .stroke(theme.danger.opacity(0.7), lineWidth: 2)
                        .scaleEffect(animateWave ? 1.5 : 1.0)
                        .opacity(animateWave ? 0 : 1)
                        .frame(width: 16, height: 16)
                        .animation(
                            Animation.easeOut(duration: 1).repeatForever(autoreverses: false),
                            value: animateWave
                        )
                        .onAppear {
                            animateWave = true
                        }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(audioCaptureManager.isRecording ? "녹음 중..." : "대기 중")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(audioCaptureManager.isRecording ? theme.danger : theme.dimText)

                if audioCaptureManager.isRecording {
                    Text(timeString(from: recordingTime))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(theme.foreground)
                }
            }

            Spacer()

            // 현재 녹음 중인 장치 표시
            if audioCaptureManager.isRecording,
               let selectedID = audioCaptureManager.selectedDeviceID,
               let device = audioCaptureManager.availableAudioDevices.first(where: { $0.id == selectedID })
            {
                HStack {
                    Image(systemName: getDeviceIcon(name: device.name))
                        .foregroundColor(theme.highlight.opacity(0.9))

                    Text(device.name)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(theme.brightText)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.secondaryBg.opacity(0.7))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBg)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        )
    }

    // 장치 아이콘 선택 헬퍼 함수
    private func getDeviceIcon(name: String) -> String {
        if name.contains("BlackHole") {
            return "waveform.circle"
        } else if name.contains("Built-in") || name.contains("내장") {
            return "speaker.wave.2.circle"
        } else if name.contains("AirPods") || name.contains("Headphones") || name.contains("헤드폰") {
            return "headphones"
        } else if name.contains("USB") || name.contains("Microphone") || name.contains("마이크") {
            return "mic.circle"
        } else if name.contains("Aggregate") || name.contains("Multi") {
            return "rectangle.3.group"
        } else {
            return "speaker.circle"
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
