//
//  ContentView.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @ObservedObject var audioCaptureManager: AudioCaptureManager
    @StateObject private var settings = AppSettings()
    @State private var logMessages: [LogMessage] = []
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var animateWave = false
    @State private var showingDeviceSelector = false
    @State private var showingSettings = false
    @State private var hoverButton: String? = nil
    @State private var isDebugMode: Bool = false  // 디버그 모드 상태
    
    // 고정 크기 정의
    private let fixedWidth: CGFloat = 800
    private let fixedHeight: CGFloat = 1000
    
    // 현재 테마 불러오기
    private var theme: SolarizedTheme {
        return SolarizedColors.themeWith(settings: settings)
    }
    
    init(audioCaptureManager: AudioCaptureManager) {
        self.audioCaptureManager = audioCaptureManager
    }
    
    var body: some View {
        ZStack {
            // 배경 그라데이션
            theme.backgroundGradient
                .ignoresSafeArea()
            
            // 미묘한 패턴 오버레이
            Rectangle()
                .fill(Color.black.opacity(0.03))
                .ignoresSafeArea()
            
            VStack(spacing: 22) {
                // 상단 헤더와 컨트롤
                headerView
                
                deviceSelectorButton
                audioLevelView
                
                // 녹음 상태 뷰
                RecordingStatusView(
                    audioCaptureManager: audioCaptureManager,
                    theme: theme,
                    recordingTime: recordingTime,
                    animateWave: $animateWave
                )
                
                controlButtonsView
                
                // 디버그 모드일 때만 로그 표시
                if isDebugMode {
                    LogView(logMessages: logMessages, theme: theme, onClear: clearLogs)
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            
            // 하단 버튼 그룹
            VStack {
                Spacer()
                HStack {
                    // 디버그 모드 토글 버튼 (좌측 하단)
                    debugModeToggle
                    
                    Spacer()
                    
                    // 설정 버튼 (우측 하단)
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(theme.dimText)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(theme.secondaryBg)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("앱 설정")
                }
            }
            .padding()
        }
        .frame(width: fixedWidth, height: fixedHeight)
        .onAppear {
            addLogMessage("애플리케이션이 시작되었습니다")
            
            // 장치 검색을 약간 지연시킵니다
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [] in
                // BlackHole이 설치되어 있는지 확인
                let hasBlackHole = audioCaptureManager.availableAudioDevices.contains { $0.name.contains("BlackHole") }
                if !hasBlackHole {
                    addLogMessage("⚠️ BlackHole 가상 오디오 드라이버가 발견되지 않았습니다")
                    addLogMessage("시스템 오디오를 캡처하려면 BlackHole을 설치하세요")
                } else {
                    addLogMessage("BlackHole 가상 오디오 드라이버가 발견되었습니다")
                    addLogMessage("시스템 환경설정에서 오디오 출력을 BlackHole로 설정하세요")
                }
            }
            
            // 알림 수신 설정
            NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowDeviceSelector"), object: nil, queue: .main) { _ in
                self.showingDeviceSelector = true
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("StartRecording"), object: nil, queue: .main) { _ in
                self.startRecording()
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("StopRecording"), object: nil, queue: .main) { _ in
                self.stopRecording()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingDeviceSelector) {
            DeviceSelectorView(
                audioCaptureManager: audioCaptureManager,
                showingDeviceSelector: $showingDeviceSelector,
                theme: theme
            )
            .frame(width: 480)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                settings: settings,
                showingSettings: $showingSettings,
                theme: theme
            )
            .frame(width: 480)
        }
    }
    
    // 헤더 뷰 (타이틀 포함)
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("시스템 오디오 캡처")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(theme.highlight)
                .shadow(color: Color.black.opacity(0.2), radius: 1)
            
            Text("시스템 사운드와 앱 오디오를 녹음하세요")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(theme.foreground)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    // 장치 선택 버튼
    private var deviceSelectorButton: some View {
        Button(action: {
            showingDeviceSelector = true
        }) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14))
                    .foregroundColor(theme.accent)
                
                Text(getCurrentDeviceName())
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(theme.brightText)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(theme.dimText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.secondaryBg)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 현재 선택된 장치 이름 가져오기
    private func getCurrentDeviceName() -> String {
        if let selectedID = audioCaptureManager.selectedDeviceID,
           let device = audioCaptureManager.availableAudioDevices.first(where: { $0.id == selectedID }) {
            return device.name
        }
        return "오디오 장치 선택"
    }
    
    // 오디오 레벨 시각화 뷰
    private var audioLevelView: some View {
        VStack(spacing: 15) {
            HStack {
                Text("오디오 레벨")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.brightText)
                
                Spacer()
                
                Text("피크: \(Int(audioCaptureManager.audioPeak * 100))%")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.dimText)
                    .animation(.easeIn, value: audioCaptureManager.audioPeak)
            }
            
            // 오디오 파형 효과
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { index in
                    AudioBar(index: index, level: audioCaptureManager.audioLevel, isRecording: audioCaptureManager.isRecording, theme: theme)
                }
            }
            .frame(height: 100)
            .padding(.vertical, 10)
            
            // 현재 오디오 레벨 미터
            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .frame(height: 6)
                        .foregroundColor(theme.secondaryBg)
                    
                    Capsule()
                        .frame(width: max(CGFloat(audioCaptureManager.audioLevel) * 300, 5), height: 6)
                        .foregroundColor(audioLevelColor)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBg)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        )
    }
    
    // 컨트롤 버튼 뷰
    private var controlButtonsView: some View {
        HStack(spacing: 20) {
            // 녹음 버튼
            Button(action: {
                if audioCaptureManager.isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack {
                    Image(systemName: audioCaptureManager.isRecording ? "stop.fill" : "record.circle")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(audioCaptureManager.isRecording ? "녹음 중지" : "녹음 시작")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(minWidth: 130)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(
                            audioCaptureManager.isRecording ?
                            theme.buttonGradient(theme.danger) :
                            theme.buttonGradient(theme.highlight)
                        )
                )
                .foregroundColor(theme.background)
            }
            .buttonStyle(PlainButtonStyle())
            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
            .onHover { hovering in
                hoverButton = hovering ? "record" : nil
            }
            
            // 로그 지우기 버튼 (디버그 모드일 때만 표시)
            if isDebugMode {
                Button(action: {
                    clearLogs()
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("로그 지우기")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .frame(minWidth: 130)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule()
                            .fill(theme.buttonGradient(theme.secondaryBg))
                    )
                    .foregroundColor(theme.brightText)
                }
                .buttonStyle(PlainButtonStyle())
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
                .onHover { hovering in
                    hoverButton = hovering ? "clear" : nil
                }
            }
        }
    }
    
    // 디버그 모드 토글 버튼
    private var debugModeToggle: some View {
        Button(action: {
            isDebugMode.toggle()
            addLogMessage(isDebugMode ? "디버그 모드 활성화" : "디버그 모드 비활성화")
        }) {
            Image(systemName: isDebugMode ? "ladybug.fill" : "ladybug")
                .font(.system(size: 18))
                .foregroundColor(isDebugMode ? theme.highlight : theme.dimText)
                .padding(8)
                .background(
                    Circle()
                        .fill(theme.secondaryBg)
                )
        }
        .buttonStyle(PlainButtonStyle())
                .help("디버그 모드 \(isDebugMode ? "비활성화" : "활성화")")
            }
            
            private var audioLevelColor: Color {
                if audioCaptureManager.audioLevel < 0.3 {
                    return theme.success.opacity(0.9)
                } else if audioCaptureManager.audioLevel < 0.7 {
                    return theme.yellow.opacity(0.9)
                } else {
                    return theme.danger.opacity(0.9)
                }
            }
            
            private func startRecording() {
                addLogMessage("녹음 시작 준비 중...")
                
                // 저장 패널 표시
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [UTType.wav]
                savePanel.nameFieldStringValue = "System_Audio_Recording_\(Date().timeIntervalSince1970)"
                
                // 패널 스타일 설정
                savePanel.appearance = NSAppearance(named: .darkAqua)
                
                addLogMessage("저장 위치 선택 대기 중...")
                
                savePanel.begin { response in
                    if response == .OK, let url = savePanel.url {
                        // 파일 확장자 로깅
                        addLogMessage("선택된 저장 경로: \(url.path)")
                        
                        // BlackHole 장치 확인
                        let hasBlackHole = self.audioCaptureManager.availableAudioDevices.contains {
                            $0.name.contains("BlackHole")
                        }
                        
                        if !hasBlackHole {
                            addLogMessage("⚠️ 경고: BlackHole 장치를 찾을 수 없습니다")
                        }
                        
                        // 현재 선택된 장치 확인
                        if let selectedID = self.audioCaptureManager.selectedDeviceID,
                           let device = self.audioCaptureManager.availableAudioDevices.first(where: { $0.id == selectedID }) {
                            addLogMessage("현재 선택된 입력 장치: \(device.name)")
                            
                            if !device.name.contains("BlackHole") {
                                addLogMessage("⚠️ 경고: BlackHole이 입력 장치로 선택되지 않았습니다")
                            }
                        } else {
                            addLogMessage("⚠️ 경고: 선택된 입력 장치가 없습니다")
                        }
                        
                        // 녹음 시작
                        self.audioCaptureManager.startRecording(to: url)
                        addLogMessage("녹음 시작: \(url.lastPathComponent)")
                        
                        // 타이머 시작
                        self.recordingTime = 0
                        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                            self.recordingTime += 1.0
                            
                            // 5초마다 오디오 피크 기록
                            if Int(self.recordingTime) % 5 == 0 {
                                let peakValue = Int(self.audioCaptureManager.audioPeak * 100)
                                
                                if peakValue < 1 {
                                    self.addLogMessage("⚠️ 오디오 피크: \(peakValue)% (오디오가 감지되지 않습니다)")
                                } else {
                                    self.addLogMessage("오디오 피크: \(peakValue)%")
                                }
                            }
                        }
                    } else {
                        self.addLogMessage("녹음 취소됨")
                    }
                }
            }
            
            private func stopRecording() {
                if let url = audioCaptureManager.getCurrentRecordingURL() {
                    addLogMessage("녹음 중지: \(url.lastPathComponent) (길이: \(timeString(from: recordingTime)))")
                } else {
                    addLogMessage("녹음 중지 (길이: \(timeString(from: recordingTime)))")
                }
                
                audioCaptureManager.stopRecording()
                timer?.invalidate()
                timer = nil
            }
            
            private func addLogMessage(_ text: String) {
                let newMessage = LogMessage(text: text)
                logMessages.insert(newMessage, at: 0)
            }
            
            private func clearLogs() {
                logMessages.removeAll()
                addLogMessage("로그를 지웠습니다")
            }
            
            private func timeString(from timeInterval: TimeInterval) -> String {
                let minutes = Int(timeInterval) / 60
                let seconds = Int(timeInterval) % 60
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
