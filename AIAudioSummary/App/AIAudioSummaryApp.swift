//
//  AIAudioSummaryApp.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import SwiftUI

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
            CommandGroup(replacing: .newItem) {}

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
