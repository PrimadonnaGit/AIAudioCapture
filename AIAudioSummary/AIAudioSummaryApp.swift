//
//  AIAudioSummaryApp.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//
import SwiftUI
import Combine
import AVFoundation
import UserNotifications

// 앱의 메인 진입점
@main
struct AudioCaptureApp: App {
    @NSApplicationDelegateAdaptor(AudioAppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(audioCaptureManager: appDelegate.audioCaptureManager)
                .frame(minWidth: 800, minHeight: 1000)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            // 기본 New 메뉴 항목 제거
            CommandGroup(replacing: .newItem) { }
            
            // 오디오 관련 메뉴 추가
            CommandMenu("오디오") {
                Button("장치 선택...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowDeviceSelector"), object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command])
                
                Divider()
                
                Button("녹음 시작") {
                    NotificationCenter.default.post(name: NSNotification.Name("StartRecording"), object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Button("녹음 중지") {
                    NotificationCenter.default.post(name: NSNotification.Name("StopRecording"), object: nil)
                }
                .keyboardShortcut(".", modifiers: [.command])
            }
        }
    }
}

// 앱 델리게이트 - 시스템 트레이 아이콘 및 기타 앱 수준 기능 관리
class AudioAppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var audioCaptureManager = AudioCaptureManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("\n===== 애플리케이션 시작 =====")
        print("macOS 버전: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        
        // 장치 검색은 지연시켜 BlackHole이 로드될 시간을 줍니다
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            print("오디오 장치 로드 중...")
            self.audioCaptureManager.loadAudioDevices()
            
            // BlackHole 설치 확인
            self.checkBlackHoleInstallation()
        }
        
        setupStatusBarItem()
        
        // 알림 수신 설정
        NotificationCenter.default.addObserver(self, selector: #selector(showDeviceSelector), name: NSNotification.Name("ShowDeviceSelector"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startRecording), name: NSNotification.Name("StartRecording"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopRecording), name: NSNotification.Name("StopRecording"), object: nil)
        
        requestMicrophoneAccess()

        
        print("===== 애플리케이션 초기화 완료 =====\n")
    }
    
    private func requestMicrophoneAccess() {
        print("마이크 접근 권한 요청 중...")
        
        // AVCaptureDevice를 사용하여 권한 요청
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 마이크 접근 권한이 허용되었습니다")
                } else {
                    print("⚠️ 마이크 접근 권한이 거부되었습니다")
                    
                    // 사용자에게 알림 표시
                    let alert = NSAlert()
                    alert.messageText = "마이크 접근 권한 필요"
                    alert.informativeText = "이 앱은 오디오를 녹음하기 위해 마이크 접근 권한이 필요합니다. 설정 > 개인 정보 보호 > 마이크에서 권한을 허용해주세요."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "설정 열기")
                    alert.addButton(withTitle: "나중에")
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        // 시스템 환경설정 열기
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }
    
    // 상태 표시줄 아이콘 설정
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
            button.action = #selector(toggleRecording)
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "시작/중지", action: #selector(toggleRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "장치 선택...", action: #selector(showDeviceSelector), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "앱 표시", action: #selector(showApp), keyEquivalent: "a"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    // BlackHole 설치 확인 및 안내
    private func checkBlackHoleInstallation() {
        print("\n----- BlackHole 드라이버 확인 -----")
        
        let hasBlackHole = audioCaptureManager.availableAudioDevices.contains { $0.name.contains("BlackHole") }
        print("BlackHole 드라이버 발견됨: \(hasBlackHole)")
        
        if hasBlackHole {
            // BlackHole 장치 정보 출력
            if let blackholeDevice = audioCaptureManager.availableAudioDevices.first(where: { $0.name.contains("BlackHole") }) {
                print("BlackHole 장치 정보: 이름=\(blackholeDevice.name), ID=\(blackholeDevice.id)")
            }
            
            // 자동으로 BlackHole 선택 시도
            if audioCaptureManager.selectedDeviceID == nil {
                if let blackholeDevice = audioCaptureManager.availableAudioDevices.first(where: { $0.name.contains("BlackHole") }) {
                    print("BlackHole을 자동으로 입력 장치로 선택합니다")
                    audioCaptureManager.changeAudioDevice(deviceID: blackholeDevice.id)
                }
            }
        } else {
            print("⚠️ BlackHole 드라이버를 찾을 수 없습니다")
            
            // 알림창 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "시스템 오디오 캡처를 위한 설정"
                alert.informativeText = "시스템 오디오(앱 소리)를 캡처하려면 가상 오디오 드라이버인 BlackHole이 필요합니다. 이 소프트웨어는 무료이며 오픈소스입니다.\n\n설치 방법:\n1. Homebrew를 통해 설치: brew install blackhole-2ch\n2. 또는 GitHub에서 다운로드하여 설치"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "GitHub에서 다운로드")
                alert.addButton(withTitle: "나중에")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "https://github.com/ExistentialAudio/BlackHole") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        print("---------------------------------\n")
    }
    
    // 녹음 시작/중지 토글
    @objc func toggleRecording() {
        if audioCaptureManager.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // 장치 선택기 표시
    @objc func showDeviceSelector() {
        NotificationCenter.default.post(name: NSNotification.Name("ShowDeviceSelector"), object: nil)
        showApp()
    }
    
    // 녹음 시작
    @objc func startRecording() {
        if audioCaptureManager.isRecording {
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.wav]
        savePanel.nameFieldStringValue = "System_Audio_Recording_\(Date().timeIntervalSince1970)"
        
        NSApp.activate(ignoringOtherApps: true)
        
        savePanel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = savePanel.url else { return }
            self.audioCaptureManager.startRecording(to: url)
            
            // 상태바 아이콘 업데이트
            if let button = self.statusItem.button {
                button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: nil)
            }
            
            // 알림 표시
            self.showNotification(title: "녹음 시작", message: "시스템 오디오 녹음이 시작되었습니다.")
        }
    }
    
    // 녹음 중지
    @objc func stopRecording() {
        if !audioCaptureManager.isRecording {
            return
        }
        
        audioCaptureManager.stopRecording()
        
        // 상태바 아이콘 업데이트
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
        }
        
        // 알림 표시
        showNotification(title: "녹음 완료", message: "시스템 오디오 녹음이 완료되었습니다.")
    }
    
    // 앱 창 표시
    @objc func showApp() {
        NSApp.activate(ignoringOtherApps: true)
        
        // 이미 열려있는 창이 있으면 앞으로 가져오기
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    // 시스템 알림 표시
    private func showNotification(title: String, message: String) {
        if #available(macOS 11.0, *) {
            // macOS 11 이상에서는 UNUserNotificationCenter 사용
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        } else {
            // 이전 버전에서는 NSUserNotification 사용
            let notification = NSUserNotificationLegacy()
            notification.title = title
            notification.informativeText = message
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenterLegacy.default.deliver(notification)
        }
    }
}

// 이전 macOS 버전 호환성을 위한 레거시 알림 클래스
@available(macOS, introduced: 10.10, deprecated: 11.0, message: "Use UserNotifications Framework's UNUserNotificationCenter instead")
class NSUserNotificationLegacy: NSObject {
    @objc var title: String?
    @objc var informativeText: String?
    @objc var soundName: String?
}

@available(macOS, introduced: 10.10, deprecated: 11.0, message: "Use UserNotifications Framework's UNUserNotificationCenter instead")
class NSUserNotificationCenterLegacy: NSObject {
    @objc static let `default` = NSUserNotificationCenterLegacy()
    
    @objc func deliver(_ notification: NSUserNotificationLegacy) {
        // 실제 구현에서는 진짜 NSUserNotificationCenter를 사용할 것입니다
        print("알림 전송: \(notification.title ?? "")")
    }
}
