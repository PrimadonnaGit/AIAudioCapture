//
//  AudioCaptureManager.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import AVFoundation
import Combine
import CoreAudio
import AudioToolbox

class AudioCaptureManager: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine!
    private var audioFile: AVAudioFile?
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var audioPeak: Float = 0.0
    
    private var levelTimer: Timer?
    private var currentRecordingURL: URL?
    
    // 사용 가능한 오디오 장치 목록
    @Published var availableAudioDevices: [(id: AudioDeviceID, name: String)] = []
    @Published var selectedDeviceID: AudioDeviceID?
    
    override init() {
        super.init()
        setupAudioEngine()
        loadAudioDevices()
    }
    
    public func loadAudioDevices() {
        // 디버깅을 위한 출력
        print("오디오 장치 로드 시작...")
        
        var availableDevices: [(id: AudioDeviceID, name: String)] = []
        
        // 모든 오디오 장치 가져오기
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize)
        
        if status != noErr {
            print("오류: 오디오 장치 속성 크기를 가져오는 데 실패했습니다 (오류 코드: \(status))")
            return
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        print("발견된 총 장치 수: \(deviceCount)")
        
        // 장치가 없으면 종료
        if deviceCount == 0 {
            print("장치를 찾을 수 없습니다.")
            self.availableAudioDevices = []
            return
        }
        
        // 장치 ID 배열 생성
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceIDs)
        
        if status != noErr {
            print("오류: 오디오 장치 ID를 가져오는 데 실패했습니다 (오류 코드: \(status))")
            return
        }
        
        // 각 장치 확인
        for deviceID in deviceIDs {
            // 장치 이름 가져오기
            if let name = getDeviceName(deviceID: deviceID) {
                // 디버깅을 위한 출력
                print("장치 발견: ID \(deviceID), 이름: \(name)")
                
                // 입력 장치 확인 - 간소화를 위해 일단 모든 장치를 추가
                availableDevices.append((id: deviceID, name: name))
            }
        }
        
        // 결과 업데이트
        DispatchQueue.main.async {
            self.availableAudioDevices = availableDevices
            
            // BlackHole을 찾아 자동 선택
            if let blackholeDevice = self.availableAudioDevices.first(where: { $0.name.contains("BlackHole") }) {
                self.selectedDeviceID = blackholeDevice.id
                print("BlackHole 오디오 장치를 자동 선택했습니다: \(blackholeDevice.name)")
            } else if !self.availableAudioDevices.isEmpty {
                self.selectedDeviceID = self.availableAudioDevices.first?.id
                print("첫 번째 오디오 장치를 선택했습니다: \(self.availableAudioDevices.first?.name ?? "Unknown")")
            }
            
            print("사용 가능한 오디오 장치: \(self.availableAudioDevices.count)개")
        }
    }
    
    // 장치 이름 가져오기 - 간소화된 버전
    public func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var name: CFString = "" as CFString
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &name)
        
        if status != noErr {
            print("장치 \(deviceID)의 이름을 가져오는 데 실패했습니다")
            return nil
        }
        
        return name as String
    }
    
    // 시스템의 모든 오디오 입력 장치 가져오기
    private func getInputAudioDevices() -> [(id: AudioDeviceID, name: String)] {
        var devices: [(id: AudioDeviceID, name: String)] = []
        
        var propertySize: UInt32 = 0
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize)
        
        if status != noErr {
            print("오디오 장치 속성 크기를 가져오는 데 실패했습니다")
            return devices
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        var addressDeviceID = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement:    kAudioObjectPropertyElementMain)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addressDeviceID,
            0,
            nil,
            &propertySize,
            &deviceIDs)
        
        if status != noErr {
            print("오디오 장치 ID를 가져오는 데 실패했습니다")
            return devices
        }
        
        for deviceID in deviceIDs {
            var hasInput = UInt32(0)
            var propertySize = UInt32(MemoryLayout<UInt32>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                            mSelector: kAudioDevicePropertyStreamConfiguration,
                            mScope: kAudioDevicePropertyScopeInput,
                            mElement: kAudioObjectPropertyElementMain)
                        
                        status = AudioObjectGetPropertyData(
                            deviceID,
                            &propertyAddress,
                            0,
                            nil,
                            &propertySize,
                            &hasInput)
                        
                        // 입력 채널이 있는 장치만 추가
                        if status == noErr && hasInput > 0 {
                            if let name = getDeviceName(deviceID: deviceID) {
                                devices.append((id: deviceID, name: name))
                                print("입력 장치 발견: \(name), ID: \(deviceID)")
                            }
                        }
                    }
                    
                    return devices
                }
                
                // 선택한 장치로 오디오 엔진 설정
                func setupAudioEngine() {
                    print("===== 오디오 엔진 설정 시작 =====")
                    audioEngine = AVAudioEngine()
                    
                    // 선택된 장치가 있는 경우 명시적으로 설정 시도
                    if let selectedID = selectedDeviceID {
                        // CoreAudio API를 사용하여 AudioUnit 파라미터 설정
                        var audioUnit = audioEngine.inputNode.audioUnit!
                        
                        // kAudioOutputUnitProperty_CurrentDevice를 설정하여 특정 장치 지정
                        var deviceID = selectedID
                        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
                        let status = AudioUnitSetProperty(
                            audioUnit,
                            kAudioOutputUnitProperty_CurrentDevice,
                            kAudioUnitScope_Global,
                            0,
                            &deviceID,
                            propertySize
                        )
                        
                        if status == noErr {
                            print("✅ 오디오 엔진 입력 장치를 ID \(selectedID)로 명시적 설정 성공")
                            
                            // 장치 이름 로깅
                            if let deviceName = getDeviceName(deviceID: selectedID) {
                                print("설정된 장치: \(deviceName)")
                            }
                        } else {
                            print("⚠️ 오디오 엔진 입력 장치 설정 실패 (오류 코드: \(status))")
                        }
                    } else {
                        print("선택된 장치 ID가 없습니다. 기본 입력 장치를 사용합니다.")
                    }
                    
                    // 입력 노드 가져오기
                    let inputNode = audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    print("입력 노드 포맷: \(format)")
                    print("입력 노드 정보: \(inputNode)")
                    
                    // 현재 시스템 오디오 설정 정보 출력
                    logCurrentAudioDevices()
                    
                    // 녹음 설정
                    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] (buffer, time) in
                        guard let self = self, let audioFile = self.audioFile else {
                            print("🔴 오디오 버퍼 처리 중 오류: audioFile이 nil입니다")
                            return
                        }
                        
                        do {
                            try audioFile.write(from: buffer)
                            
                            // 무음 감지 로직 추가
                            let channelData = buffer.floatChannelData!
                            let channelDataValue = channelData.pointee
                            var sum: Float = 0.0
                            
                            for i in 0..<Int(buffer.frameLength) {
                                sum += abs(channelDataValue[i])
                            }
                            
                            // 현재 시간
                            let currentTime = Date().timeIntervalSince1970
                            
                            // 무음 감지 및 주기적인 로깅
                            if sum < 0.001 && buffer.frameLength > 0 {
                                if Int(currentTime) % 5 == 0 {  // 5초마다 로깅
                                    print("⚠️ 오디오 버퍼에 거의 무음이 감지됨 (sum: \(sum), 버퍼 길이: \(buffer.frameLength))")
                                }
                            } else if Int(currentTime) % 10 == 0 {  // 10초마다 정상 데이터 로깅
                                print("✅ 버퍼 데이터: 길이=\(buffer.frameLength), 채널=\(buffer.format.channelCount), 신호 합계=\(sum)")
                            }
                            
                            // 오디오 레벨 계산
                            self.calculateAudioLevels(buffer)
                        } catch {
                            print("🔴 오디오 파일 쓰기 오류: \(error.localizedDescription)")
                            print("🔴 오류 세부 정보: \(error)")
                        }
                    }
                    print("===== 오디오 엔진 설정 완료 =====")
                }
                
                private func logCurrentAudioDevices() {
                    print("\n----- 현재 시스템 오디오 설정 -----")
                    
                    // 기본 입력 장치 확인
                    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
                    var propertyAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioHardwarePropertyDefaultInputDevice,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain)
                    
                    var inputDeviceID: AudioDeviceID = 0
                    let status1 = AudioObjectGetPropertyData(
                        AudioObjectID(kAudioObjectSystemObject),
                        &propertyAddress,
                        0,
                        nil,
                        &propertySize,
                        &inputDeviceID)
                    
                    if status1 == noErr, let inputName = getDeviceName(deviceID: inputDeviceID) {
                        print("기본 입력 장치: \(inputName) (ID: \(inputDeviceID))")
                    } else {
                        print("기본 입력 장치를 확인할 수 없습니다")
                    }
                    
                    // 기본 출력 장치 확인
                    propertyAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice
                    var outputDeviceID: AudioDeviceID = 0
                    let status2 = AudioObjectGetPropertyData(
                        AudioObjectID(kAudioObjectSystemObject),
                        &propertyAddress,
                        0,
                        nil,
                        &propertySize,
                        &outputDeviceID)
                    
                    if status2 == noErr, let outputName = getDeviceName(deviceID: outputDeviceID) {
                        print("기본 출력 장치: \(outputName) (ID: \(outputDeviceID))")
                    } else {
                        print("기본 출력 장치를 확인할 수 없습니다")
                    }
                    
                    // 현재 선택된 장치 정보
                    if let selectedID = selectedDeviceID,
                       let selectedName = getDeviceName(deviceID: selectedID) {
                        print("현재 선택된 장치: \(selectedName) (ID: \(selectedID))")
                    } else {
                        print("현재 선택된 장치 없음")
                    }
                    
                    print("------------------------------\n")
                }
                
                // 오디오 장치 변경
                func changeAudioDevice(deviceID: AudioDeviceID) {
                    print("\n----- 오디오 장치 변경 시작 -----")
                    print("새 장치 ID: \(deviceID)")
                    
                    // 장치 이름 로깅
                    if let deviceName = getDeviceName(deviceID: deviceID) {
                        print("선택된 장치: \(deviceName)")
                    }
                    
                    // 현재 녹음 중이면 중지
                    let wasRecording = isRecording
                    if wasRecording {
                        print("녹음 중이므로 일시 중지합니다")
                        stopRecording()
                    }
                    
                    // 오디오 엔진 재설정 전 정리
                    if audioEngine.isRunning {
                        print("오디오 엔진 중지 중...")
                        audioEngine.stop()
                    }
                    
                    // 안전하게 탭 제거 시도
                    print("오디오 입력 노드 탭 제거 시도...")
                    do {
                        audioEngine.inputNode.removeTap(onBus: 0)
                        print("✅ 오디오 입력 노드 탭 제거 성공")
                    } catch {
                        // 일부 경우에 탭이 설치되어 있지 않으면 오류가 발생할 수 있음
                        print("ℹ️ 입력 노드에 설치된 탭이 없습니다")
                    }
                    
                    // 시스템 기본 입력 장치 변경
                    do {
                        // 현재 기본 입력 장치 가져오기 (나중에 복원을 위해)
                        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
                        var propertyAddress = AudioObjectPropertyAddress(
                            mSelector: kAudioHardwarePropertyDefaultInputDevice,
                            mScope: kAudioObjectPropertyScopeGlobal,
                            mElement: kAudioObjectPropertyElementMain)
                        
                        var originalDeviceID: AudioDeviceID = 0
                        var status = AudioObjectGetPropertyData(
                            AudioObjectID(kAudioObjectSystemObject),
                            &propertyAddress,
                            0,
                            nil,
                            &size,
                            &originalDeviceID)
                        
                        if status != noErr {
                            print("⚠️ 현재 기본 입력 장치를 가져오는 데 실패했습니다 (오류 코드: \(status))")
                        }
                        
                        // 새 장치로 변경
                        var newDeviceID = deviceID
                        status = AudioObjectSetPropertyData(
                            AudioObjectID(kAudioObjectSystemObject),
                            &propertyAddress,
                            0,
                            nil,
                            UInt32(MemoryLayout<AudioDeviceID>.size),
                            &newDeviceID)
                        
                        if status != noErr {
                            print("⚠️ 입력 장치를 변경하는 데 실패했습니다 (오류 코드: \(status))")
                        } else {
                            print("✅ 시스템 입력 장치가 변경되었습니다")
                        }
                        
                        // 장치 변경 후 약간의 지연을 줌
                        Thread.sleep(forTimeInterval: 0.5)
                        
                        // 오디오 엔진 재설정
                        print("오디오 엔진 재설정 중...")
                        setupAudioEngine()
                        
                        // 오디오 라우팅 검증
                        if verifyAudioRouting() {
                            print("✅ 오디오 라우팅이 올바르게 설정되었습니다")
                        }
                        
                        selectedDeviceID = deviceID
                        
                        // 이전에 녹음 중이었다면 녹음 재개
                        if wasRecording, let url = currentRecordingURL {
                            print("이전 녹음을 재개합니다: \(url.path)")
                            startRecording(to: url)
                        }
                        
                        print("✅ 오디오 장치 변경 완료")
                    } catch {
                        print("🔴 오디오 장치 변경 오류: \(error)")
                    }
                    
                    print("----- 오디오 장치 변경 완료 -----\n")
                }
                
                func verifyAudioRouting() -> Bool {
                    print("\n----- 오디오 라우팅 검증 -----")
                    var isRoutingCorrect = true
                    
                    // 1. 선택된 입력 장치가 BlackHole인지 확인
                    if let selectedID = selectedDeviceID,
                       let inputName = getDeviceName(deviceID: selectedID) {
                        print("현재 선택된 입력 장치: \(inputName)")
                        
                        if !inputName.contains("BlackHole") {
                            print("⚠️ 선택된 입력 장치가 BlackHole이 아닙니다")
                            isRoutingCorrect = false
                        }
                    } else {
                        print("⚠️ 선택된 입력 장치가 없습니다")
                        isRoutingCorrect = false
                    }
                    
                    // 2. 시스템 출력이 BlackHole로 설정되어 있는지 확인
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
                    
                    if status == noErr {
                        if let outputName = getDeviceName(deviceID: outputDeviceID) {
                            print("현재 시스템 출력 장치: \(outputName)")
                            
                            if !outputName.contains("BlackHole") {
                                print("⚠️ 시스템 출력이 BlackHole로 설정되어 있지 않습니다")
                                isRoutingCorrect = false
                            }
                        } else {
                            print("⚠️ 출력 장치 이름을 가져올 수 없습니다")
                            isRoutingCorrect = false
                        }
                    } else {
                        print("⚠️ 출력 장치 정보를 가져올 수 없습니다 (오류 코드: \(status))")
                        isRoutingCorrect = false
                    }
                    
                    // 3. 오디오 엔진이 올바른 장치를 사용하는지 확인
                    let inputNode = audioEngine.inputNode
                    if let audioUnit = inputNode.audioUnit {
                        var currentDeviceID: AudioDeviceID = 0
                        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
                        
                        let status = AudioUnitGetProperty(
                            audioUnit,
                            kAudioOutputUnitProperty_CurrentDevice,
                            kAudioUnitScope_Global,
                            0,
                            &currentDeviceID,
                            &propertySize)
                        
                        if status == noErr {
                            if let deviceName = getDeviceName(deviceID: currentDeviceID) {
                                print("AVAudioEngine이 사용 중인 장치: \(deviceName) (ID: \(currentDeviceID))")
                                
                                if currentDeviceID != selectedDeviceID {
                                    print("⚠️ AVAudioEngine이 선택된 장치를 사용하고 있지 않습니다")
                                    isRoutingCorrect = false
                                }
                            }
                        } else {
                            print("⚠️ AVAudioEngine 장치 정보를 가져올 수 없습니다 (오류 코드: \(status))")
                        }
                    }
                    
                    // 종합 결과
                    if isRoutingCorrect {
                        print("✅ 오디오 라우팅이 올바르게 설정되어 있습니다")
                    } else {
                        print("⚠️ 오디오 라우팅에 문제가 있습니다. 올바른 설정 방법:")
                        print("1. 시스템 환경설정 > 사운드 > 출력에서 'BlackHole 2ch'를 선택하세요")
                        print("2. 앱에서 입력 장치로 'BlackHole 2ch'를 선택하세요")
                        print("3. 소리를 들으려면 '다중 출력 장치'를 구성하거나 Loopback 앱을 사용하세요")
                    }
                    
                    print("----- 오디오 라우팅 검증 완료 -----\n")
                    return isRoutingCorrect
                }
                
                private func calculateAudioLevels(_ buffer: AVAudioPCMBuffer) {
                    guard let channelData = buffer.floatChannelData else { return }
                    
                    let channelDataValue = channelData.pointee
                    var sum: Float = 0.0
                    
                    // 모든 샘플의 제곱 합계 계산
                    for i in 0..<Int(buffer.frameLength) {
                        let sample = channelDataValue[i]
                        sum += sample * sample
                    }
                    
                    // RMS(Root Mean Square) 계산
                    let rms = sqrt(sum / Float(buffer.frameLength))
                    
                    // RMS 값을 0...1 범위로 변환 (보통 오디오 값은 -1...1 범위)
                    let level = min(rms * 5, 1.0) // 증폭을 위해 5를 곱함
                    
                    DispatchQueue.main.async {
                        self.audioLevel = level
                        if level > self.audioPeak {
                            self.audioPeak = level
                        } else {
                            self.audioPeak = self.audioPeak * 0.95 // 점진적으로 피크 감소
                        }
                    }
                }
                
                func startRecording(to url: URL) {
                    print("\n===== 녹음 시작 시도 =====")
                    
                    if isRecording {
                        print("이미 녹음 중입니다. 기존 녹음을 중지합니다.")
                        stopRecording()
                    }
                    
                    // 오디오 라우팅 검증
                    if !verifyAudioRouting() {
                        print("⚠️ 오디오 라우팅이 올바르게 설정되지 않았습니다")
                        
                        // 사용자에게 알림 표시 코드는 여기에 추가
                        // 그러나 록음은 진행할 수 있도록 합니다 (디버깅 목적)
                        print("경고가 있지만 녹음을 계속 진행합니다...")
                    }
                    
                    currentRecordingURL = url
                    print("녹음 파일 경로: \(url.path)")
                    
                    // 입력 노드의 실제 포맷을 사용
                    let format = audioEngine.inputNode.outputFormat(forBus: 0)
                    print("입력 포맷: 샘플레이트=\(format.sampleRate), 채널=\(format.channelCount)")
                    
                    // BlackHole이 선택되었는지 확인
                    let isBlackHoleSelected = selectedDeviceID != nil &&
                    availableAudioDevices.first(where: { $0.id == selectedDeviceID })?.name.contains("BlackHole") == true
                    print("BlackHole 장치 선택됨: \(isBlackHoleSelected)")
                    
                    // 오디오 파일 설정 - PCM 형식 사용
                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatLinearPCM),
                        AVSampleRateKey: format.sampleRate,
                        AVNumberOfChannelsKey: format.channelCount,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false
                    ]
                    
                    print("녹음 설정: \(settings)")
                    
                    do {
                        audioFile = try AVAudioFile(forWriting: url, settings: settings)
                        print("✅ 오디오 파일 생성 성공")
                        
                        // 오디오 엔진 상태 확인 및 시작
                        if !audioEngine.isRunning {
                            print("오디오 엔진 시작 중...")
                            try audioEngine.start()
                            print("✅ 오디오 엔진 시작 성공")
                            
                            // 장치 연결 확인을 위한 추가 테스트
                            if let audioUnit = audioEngine.inputNode.audioUnit {
                                var deviceID: AudioDeviceID = 0
                                var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
                                
                                let status = AudioUnitGetProperty(
                                    audioUnit,
                                    kAudioOutputUnitProperty_CurrentDevice,
                                    kAudioUnitScope_Global,
                                    0,
                                    &deviceID,
                                    &propertySize)
                                
                                if status == noErr, let deviceName = getDeviceName(deviceID: deviceID) {
                                    print("오디오 엔진이 사용 중인 장치: \(deviceName) (ID: \(deviceID))")
                                }
                            }
                        } else {
                            print("오디오 엔진이 이미 실행 중입니다")
                        }
                        
                        isRecording = true
                        print("✅ 녹음이 성공적으로 시작되었습니다")
                        
                        // 시스템 오디오 상태 다시 확인
                        logCurrentAudioDevices()
                        
                        // 녹음 시작 3초 후 추가 확인
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                            guard let self = self, self.isRecording else { return }
                            
                            print("\n----- 녹음 시작 3초 후 상태 확인 -----")
                            
                            // 파일 크기 확인
                            if let url = self.currentRecordingURL {
                                do {
                                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                                    if let fileSize = fileAttributes[.size] as? Int64 {
                                        let fileSizeInKB = Double(fileSize) / 1024
                                        print("현재 녹음 파일 크기: \(String(format: "%.2f", fileSizeInKB)) KB")
                                        
                                        if fileSize < 1000 { // 1KB 미만이면 경고
                                            print("⚠️ 녹음 중이지만 파일 크기가 매우 작습니다. 오디오 데이터가 제대로 기록되지 않을 수 있습니다.")
                                        }
                                    }
                                } catch {
                                    print("파일 속성을 확인할 수 없습니다: \(error)")
                                }
                            }
                            
                            // 오디오 레벨 확인
                            if self.audioLevel < 0.01 {
                                print("⚠️ 오디오 레벨이 매우 낮습니다 (\(self.audioLevel)). 가능한 원인:")
                                print("1. 시스템 출력이 BlackHole로 설정되지 않았습니다")
                                print("2. 재생 중인 오디오가 없습니다")
                                print("3. 볼륨이 너무 낮습니다")
                            } else {
                                print("✅ 오디오 레벨: \(self.audioLevel)")
                            }
                            
                            print("----- 녹음 상태 확인 완료 -----\n")
                        }
                    } catch {
                        print("🔴 녹음 시작 오류: \(error.localizedDescription)")
                        print("🔴 오류 세부 정보: \(error)")
                    }
                    
                    print("===== 녹음 시작 완료 =====\n")
                }
                
                func stopRecording() {
                    print("\n===== 녹음 중지 시도 =====")
                    
                    if isRecording {
                        if let url = currentRecordingURL {
                            print("녹음 파일: \(url.path)")
                            
                            // 파일 크기 확인
                            do {
                                let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                                if let fileSize = fileAttributes[.size] as? Int64 {
                                    let fileSizeInMB = Double(fileSize) / (1024 * 1024)
                                    print("녹음된 파일 크기: \(String(format: "%.2f", fileSizeInMB)) MB")
                                    
                                    if fileSize < 1000 { // 1KB 미만이면 경고
                                        print("⚠️ 파일 크기가 매우 작습니다. 오디오가 제대로 녹음되지 않았을 수 있습니다.")
                                    }
                                }
                            } catch {
                                print("파일 속성을 확인할 수 없습니다: \(error)")
                            }
                        }
                        
                        print("오디오 탭 제거 중...")
                        audioEngine.inputNode.removeTap(onBus: 0)
                        
                        if audioEngine.isRunning {
                            print("오디오 엔진 중지 중...")
                            audioEngine.stop()
                        }
                        
                        audioFile = nil
                        isRecording = false
                        print("✅ 녹음이 중지되었습니다")
                        
                        // 오디오 엔진 재설정
                        print("오디오 엔진 재설정 중...")
                        setupAudioEngine()
                    } else {
                        print("현재 녹음 중이 아닙니다")
                    }
                    
                    print("===== 녹음 중지 완료 =====\n")
                }
                
                // 현재 녹음 파일 URL 반환
                func getCurrentRecordingURL() -> URL? {
                    return currentRecordingURL
                }
                
                // 다중출력장치 생성 및 설정 함수
                func setupMultiOutputDevice() -> Bool {
                    // AudioDeviceUtils로 옮긴 코드 호출
                    return AudioDeviceUtils.shared.setupMultiOutputDevice(availableDevices: availableAudioDevices) { deviceID in
                        self.changeAudioDevice(deviceID: deviceID)
                    }
                }
            }
