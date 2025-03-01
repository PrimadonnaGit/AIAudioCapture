//
//  AudioDeviceUtils.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation

class AudioDeviceUtils {
    static let shared = AudioDeviceUtils()

    private init() {}

    // 장치 UID 가져오기
    func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var deviceUID: CFString = "" as CFString
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &deviceUID
        )

        if status != noErr {
            print("장치 \(deviceID)의 UID를 가져오는 데 실패했습니다")
            return nil
        }

        return deviceUID as String
    }

    // 출력 장치 목록 가져오기 - 유틸리티 용도로 유지
    func getOutputAudioDevices(devices: [(id: AudioDeviceID, name: String)]) -> [(id: AudioDeviceID, name: String)] {
        print("물리적 출력 장치 검색 중...")
        var outputDevices: [(id: AudioDeviceID, name: String)] = []

        // 알려진 출력 장치 키워드로 필터링
        for device in devices {
            let isLikelyOutputDevice = device.name.contains("Output") ||
                device.name.contains("Speakers") ||
                device.name.contains("Headphones") ||
                device.name.contains("Built-in") ||
                device.name.contains("내장") ||
                device.name.contains("AirPods") ||
                device.name.contains("USB") ||
                device.name.contains("HDMI") ||
                device.name.contains("DisplayPort")

            let isNotVirtualDevice = !device.name.contains("BlackHole") &&
                !device.name.contains("Soundflower") &&
                !device.name.contains("Loopback")

            if isLikelyOutputDevice, isNotVirtualDevice {
                outputDevices.append(device)
                print("출력 장치 발견: \(device.name), ID: \(device.id)")
            }
        }

        return outputDevices
    }
}
