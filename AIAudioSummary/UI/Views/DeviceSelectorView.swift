//
//  DeviceSelectorView.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI

struct DeviceSelectorView: View {
    @ObservedObject var audioCaptureManager: AudioCaptureManager
    @Binding var showingDeviceSelector: Bool
    let theme: SolarizedTheme

    // BlackHole 및 가상 오디오 장치 필터링
    private var filteredDevices: [(id: AudioDeviceID, name: String)] {
        let virtualDevices = audioCaptureManager.availableAudioDevices.filter { device in
            // BlackHole 장치 우선 포함
            device.name.contains("BlackHole") ||
                // 기타 가상 오디오 장치 옵션 (필요한 경우)
                device.name.contains("Soundflower") ||
                device.name.contains("Loopback") ||
                device.name.contains("Virtual")
        }

        // 가상 장치가 없으면 모든 장치 표시
        if virtualDevices.isEmpty {
            return audioCaptureManager.availableAudioDevices
        }

        return virtualDevices
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 헤더
                VStack(spacing: 6) {
                    Text("시스템 오디오 캡처용 장치 선택")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.highlight)

                    Text("BlackHole을 선택하여 시스템 오디오를 캡처하세요")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(theme.dimText)
                }
                .padding(.top, 20)

                if filteredDevices.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 30))
                            .foregroundColor(theme.warning)
                            .padding(.bottom, 10)

                        Text("BlackHole 가상 오디오 장치를 찾을 수 없습니다")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.brightText)

                        Text("시스템 오디오 캡처를 위해서는 BlackHole과 같은 가상 오디오 장치가 필요합니다.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(theme.dimText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 40)
                } else {
                    // 장치 목록
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(filteredDevices, id: \.id) { device in
                                HStack {
                                    // 장치 아이콘 (장치 유형별로 다른 아이콘)
                                    Image(systemName: getDeviceIcon(name: device.name))
                                        .font(.system(size: 15))
                                        .foregroundColor(isBlackHoleDevice(name: device.name) ? theme.highlight : theme.foreground)
                                        .frame(width: 24)

                                    Text(device.name)
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(isBlackHoleDevice(name: device.name) ? theme.highlight : theme.brightText)

                                    Spacer()

                                    if audioCaptureManager.selectedDeviceID == device.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(theme.highlight)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(audioCaptureManager.selectedDeviceID == device.id ?
                                            theme.secondaryBg.opacity(0.6) :
                                            Color.clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    audioCaptureManager.changeAudioDevice(deviceID: device.id)
                                    showingDeviceSelector = false
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 200)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.background.opacity(0.5))
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    )
                }

                Divider()
                    .background(theme.dimText.opacity(0.2))

                VStack(alignment: .leading, spacing: 12) {
                    Text("시스템 오디오 캡처 방법:")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.brightText)

                    instructionRow(number: "1", text: "BlackHole 가상 오디오 드라이버가 설치되어 있는지 확인하세요")
                    instructionRow(number: "2", text: "시스템 환경설정 > 사운드 > 출력에서 'BlackHole 2ch'를 선택하세요")
                    instructionRow(number: "3", text: "위 장치 목록에서 'BlackHole 2ch'를 선택하세요")
                    instructionRow(number: "4", text: "녹음 버튼을 눌러 시스템 오디오를 캡처하세요")

                    Text("※ 시스템 소리를 들으면서 녹음하려면 시스템 '사운드' 설정에서 직접 다중 출력 장치를 구성하세요")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(theme.yellow)
                        .padding(.top, 4)

                    // BlackHole 설치 버튼 추가
                    if filteredDevices.isEmpty {
                        Button(action: {
                            if let url = URL(string: "https://github.com/ExistentialAudio/BlackHole") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("BlackHole 다운로드")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.background)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                Capsule()
                                    .fill(theme.buttonGradient(theme.highlight))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.secondaryBg.opacity(0.5))
                )

                // 닫기 버튼
                Button(action: {
                    showingDeviceSelector = false
                }) {
                    Text("닫기")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(theme.background)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(
                            Capsule()
                                .fill(theme.buttonGradient(theme.accent))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 16)
            }
            .padding(20)
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

    // 지시사항 행 헬퍼 함수
    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(theme.highlight)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(theme.secondaryBg.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                )

            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    // BlackHole 장치 확인 헬퍼 함수
    private func isBlackHoleDevice(name: String) -> Bool {
        return name.contains("BlackHole")
    }
}
