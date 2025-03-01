//
//  LogMessage.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import Foundation

// 로그 메시지 구조체
struct LogMessage: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let text: String
}

// AudioDeviceID 타입 추가
typealias AudioDeviceID = UInt32

