//
//  AudioDeviceUtils.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox

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
            mElement: kAudioObjectPropertyElementMain)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &deviceUID)
        
        if status != noErr {
            print("장치 \(deviceID)의 UID를 가져오는 데 실패했습니다")
            return nil
        }
        
        return deviceUID as String
    }
    
    // 출력 장치 목록 가져오기
    func getOutputAudioDevices(devices: [(id: AudioDeviceID, name: String)]) -> [(id: AudioDeviceID, name: String)] {
        print("물리적 출력 장치 검색 중...")
        var outputDevices: [(id: AudioDeviceID, name: String)] = []
        
        // 모든 오디오 장치 가져오기
        for device in devices {
            // 일부 알려진 출력 장치 키워드로 필터링
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
                                     
            // 멀티-아웃풋 장치는 제외 (다중출력장치로 다중출력장치를 생성하면 오류 발생)
            let isNotAggregateDevice = !device.name.contains("Aggregate") &&
                                       !device.name.contains("Multi-Output")
            
            if isLikelyOutputDevice && isNotVirtualDevice && isNotAggregateDevice {
                outputDevices.append(device)
                print("적합한 출력 장치 발견: \(device.name), ID: \(device.id)")
            }
        }
        
        return outputDevices
    }
    
    // 기존 Aggregate Device 찾기
    func findExistingAggregateDevices(devices: [(id: AudioDeviceID, name: String)]) -> [AudioDeviceID] {
        var aggregateDevices: [AudioDeviceID] = []
        
        // 각 장치가 Aggregate Device인지 확인 - 이름으로 확인
        for device in devices {
            if device.name.contains("Aggregate") || device.name.contains("Multi-Output") {
                aggregateDevices.append(device.id)
                print("다중출력장치 발견: \(device.name), ID: \(device.id)")
            }
        }
        
        return aggregateDevices
    }
    
    // Aggregate Device 생성
    func createAggregateDevice(deviceName: String, mainDeviceID: AudioDeviceID, secondDeviceID: AudioDeviceID) -> AudioDeviceID? {
        print("새 다중출력장치 생성 시도: \(deviceName)")
        
        // AudioObjectID를 CFString으로 변환
        let mainDeviceUID = getDeviceUID(deviceID: mainDeviceID)
        let secondDeviceUID = getDeviceUID(deviceID: secondDeviceID)
        
        guard let mainUID = mainDeviceUID, let secondUID = secondDeviceUID else {
            print("⚠️ 장치 UID를 가져오는 데 실패했습니다")
            return nil
        }
        
        print("메인 장치 UID: \(mainUID), 보조 장치 UID: \(secondUID)")
        
        // 고유한 Aggregate Device UID 생성
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let dateString = dateFormatter.string(from: Date())
        let aggregateUID = "com.yourdomain.aggregate.\(dateString)"
        
        // Aggregate Device 생성 Dictionary 설정 - 문자열 키 사용
        let aggDict: [String: Any] = [
            "aggregate-device-name": deviceName,
            "aggregate-device-uid": aggregateUID,
            "aggregate-device-clock-drift": UInt32(0),
            "aggregate-device-sub-list": [
                [
                    "uid": mainUID,
                    "output-channels": UInt32(2),
                    "input-channels": UInt32(0)
                ],
                [
                    "uid": secondUID,
                    "output-channels": UInt32(2),
                    "input-channels": UInt32(0)
                ]
            ]
        ]
        
        // Aggregate Device 생성
        var aggregateDeviceID: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(aggDict as CFDictionary, &aggregateDeviceID)
        
        if status != noErr {
            print("⚠️ 다중출력장치 생성 실패 (오류 코드: \(status))")
            return nil
        }
        
        print("✅ 다중출력장치 생성 성공: ID \(aggregateDeviceID)")
        
        return aggregateDeviceID
    }
    
    // Aggregate Device 삭제
    func destroyAggregateDevice(deviceID: AudioDeviceID) -> Bool {
        print("다중출력장치 삭제 시도: ID \(deviceID)")
        
        let status = AudioHardwareDestroyAggregateDevice(deviceID)
        
        if status != noErr {
            print("⚠️ 다중출력장치 삭제 실패 (오류 코드: \(status))")
            return false
        }
        
        return true
    }
    
    // 다중출력장치 설정
    func setupMultiOutputDevice(availableDevices: [(id: AudioDeviceID, name: String)], onDeviceSelected: @escaping (AudioDeviceID) -> Void) -> Bool {
        print("\n===== 다중출력장치 설정 시작 =====")
        
        // 1. BlackHole 장치 찾기
        guard let blackholeDevice = availableDevices.first(where: { $0.name.contains("BlackHole") }) else {
            print("⚠️ BlackHole 장치를 찾을 수 없습니다")
            return false
        }
        
        print("BlackHole 장치 발견: \(blackholeDevice.name) (ID: \(blackholeDevice.id))")
        
        // 지연 추가 (장치 감지 안정성 향상)
        Thread.sleep(forTimeInterval: 0.5)
        
        // 2. 물리적 출력 장치 찾기
        let outputDevices = getOutputAudioDevices(devices: availableDevices)
        
        if outputDevices.isEmpty {
            print("⚠️ 적합한 물리적 출력 장치를 찾을 수 없습니다")
            
            // 대안: 현재 기본 출력 장치 사용 시도
            var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            
            var outputDeviceID: AudioDeviceID = 0
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &outputDeviceID)
            
            if status == noErr, let outputDeviceName = AudioCaptureManager().getDeviceName(deviceID: outputDeviceID) {
                print("현재 기본 출력 장치 사용 시도: \(outputDeviceName) (ID: \(outputDeviceID))")
                
                // BlackHole이 아니고 다중출력장치가 아닌지 확인
                if !outputDeviceName.contains("BlackHole") &&
                   !outputDeviceName.contains("Aggregate") &&
                   !outputDeviceName.contains("Multi-Output") {
                    
                    // 이 장치로 계속 진행
                    let mainDevice = (id: outputDeviceID, name: outputDeviceName)
                    return setupMultiOutputWithDevices(mainDevice: mainDevice, blackholeDevice: blackholeDevice, onDeviceSelected: onDeviceSelected)
                } else {
                    print("⚠️ 현재 기본 출력이 가상 장치이거나 다중출력장치입니다. 직접 선택이 필요합니다.")
                    return false
                }
            } else {
                print("⚠️ 기본 출력 장치를 가져오는 데 실패했습니다")
                return false
            }
        }
        
        // 일반적으로 내장 스피커나 헤드폰을 우선 사용
        let mainDevice: (id: AudioDeviceID, name: String)
        if let builtIn = outputDevices.first(where: { $0.name.contains("내장") || $0.name.contains("Built-in") || $0.name.contains("MacBook") }) {
            mainDevice = builtIn
        } else {
            // 그 외에는 첫 번째 물리적 출력 장치 사용
            mainDevice = outputDevices[0]
        }
        
        return setupMultiOutputWithDevices(mainDevice: mainDevice, blackholeDevice: blackholeDevice, onDeviceSelected: onDeviceSelected)
    }
    
    // 실제 다중출력장치 생성 및 설정 로직을 분리
    private func setupMultiOutputWithDevices(mainDevice: (id: AudioDeviceID, name: String), blackholeDevice: (id: AudioDeviceID, name: String), onDeviceSelected: @escaping (AudioDeviceID) -> Void) -> Bool {
        print("다중출력장치 구성 준비: \(mainDevice.name) (\(mainDevice.id)) + BlackHole (\(blackholeDevice.id))")
        
        // 1. 이미 존재하는 다중출력장치 확인 및 삭제
        let existingAggregateDevices = findExistingAggregateDevices(devices: [(id: mainDevice.id, name: mainDevice.name), blackholeDevice])
        
        for deviceID in existingAggregateDevices {
            if let name = AudioCaptureManager().getDeviceName(deviceID: deviceID), name.contains("BlackHole Multi-Output") {
                print("기존 다중출력장치 발견: \(name), 삭제 시도...")
                
                if destroyAggregateDevice(deviceID: deviceID) {
                    print("✅ 기존 다중출력장치 삭제 성공")
                } else {
                    print("⚠️ 기존 다중출력장치 삭제 실패")
                }
            }
        }
        
        // 2. 새로운 다중출력장치 생성
        if let aggregateDeviceID = createAggregateDevice(
            deviceName: "BlackHole Multi-Output",
            mainDeviceID: mainDevice.id,
            secondDeviceID: blackholeDevice.id
        ) {
            // 3. 생성된 다중출력장치를 기본 출력으로 설정
            var newOutputDevice = aggregateDeviceID
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
                
            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &newOutputDevice)
            
            if status != noErr {
                print("⚠️ 다중출력장치를 기본 출력으로 설정하는 데 실패했습니다")
            } else {
                print("✅ 다중출력장치가 기본 출력으로 설정되었습니다")
            }
            
            // 4. 입력 장치로 BlackHole 선택
            onDeviceSelected(blackholeDevice.id)
            
            print("===== 다중출력장치 설정 완료 =====\n")
            return true
        } else {
            print("⚠️ 다중출력장치 생성에 실패했습니다")
        }
        
        print("===== 다중출력장치 설정 실패 =====\n")
        return false
    }
}
