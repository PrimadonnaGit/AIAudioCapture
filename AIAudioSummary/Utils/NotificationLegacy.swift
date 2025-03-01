//
//  NotificationLegacy.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import Foundation

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
