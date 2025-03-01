//
//  AudioCaptureManager.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import AudioToolbox
import AVFoundation
import Combine
import CoreAudio

class AudioCaptureManager: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine!
    private var audioFile: AVAudioFile?
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var audioPeak: Float = 0.0

    private var levelTimer: Timer?
    private var currentRecordingURL: URL?

    private var isMonitoring = false

    // 장치 변경 중인지 추적하는 플래그 추가
    private var isChangingDevice = false
    private var hasTapInstalled = false

    // 사용 가능한 오디오 장치 목록
    @Published var availableAudioDevices: [(id: AudioDeviceID, name: String)] = []
    @Published var selectedDeviceID: AudioDeviceID?

    override init() {
        super.init()
        setupAudioEngine()
        loadAudioDevices()
        setupAudioRouteChangeListener()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startAudioMonitoring()
        }
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
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize
        )

        if status != noErr {
            print("오류: 오디오 장치 속성 크기를 가져오는 데 실패했습니다 (오류 코드: \(status))")
            return
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        print("발견된 총 장치 수: \(deviceCount)")

        // 장치가 없으면 종료
        if deviceCount == 0 {
            print("장치를 찾을 수 없습니다.")
            availableAudioDevices = []
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
            &deviceIDs
        )

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
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &name
        )

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
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize
        )

        if status != noErr {
            print("오디오 장치 속성 크기를 가져오는 데 실패했습니다")
            return devices
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        var addressDeviceID = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addressDeviceID,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )

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
                mElement: kAudioObjectPropertyElementMain
            )

            status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &hasInput
            )

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

        // 여기서는 탭을 설치하지 않음 - startAudioMonitoring()에서 처리

        print("===== 오디오 엔진 설정 완료 =====")
    }

    // 오디오 모니터링 시작 함수 수정
    func startAudioMonitoring() {
        // 이미 모니터링 중이면 중복 실행 방지
        if isMonitoring {
            print("이미 오디오 모니터링 중입니다")
            return
        }

        print("오디오 레벨 모니터링 시작...")

        // 기존 탭이 설치되어 있다면 먼저 제거
        if hasTapInstalled {
            print("기존 탭 제거 중...")
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }

        // 오디오 엔진 초기화 확인
        if audioEngine == nil {
            print("⚠️ 오디오 엔진이 초기화되지 않았습니다")
            return
        }

        do {
            // 입력 노드 가져오기
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            // 오디오 탭 설치 (파일에 저장하지 않고 레벨만 모니터링)
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                guard let self = self else { return }

                // 녹음 중이면 이 버퍼를 처리하지 않음 (이미 녹음 코드에서 처리됨)
                if self.isRecording {
                    return
                }

                // 오디오 레벨 계산
                self.calculateAudioLevels(buffer)

                // 주기적으로 오디오 신호가 있는지 체크 (디버깅 용도)
                let channelData = buffer.floatChannelData!
                let channelDataValue = channelData.pointee
                var sum: Float = 0.0

                for i in 0 ..< Int(buffer.frameLength) {
                    sum += abs(channelDataValue[i])
                }

                // 5초마다 로그 출력 (디버깅용)
                let currentTime = Date().timeIntervalSince1970
                if Int(currentTime) % 5 == 0 && sum > 0.001 {
                    print("✅ 오디오 신호 감지됨 (레벨: \(self.audioLevel))")
                }
            }

            // 탭 설치 상태 업데이트
            hasTapInstalled = true

            // 오디오 엔진이 실행 중이 아니면 시작
            if !audioEngine.isRunning {
                try audioEngine.start()
                print("✅ 오디오 엔진 시작됨")
            }

            isMonitoring = true
            print("✅ 오디오 레벨 모니터링이 시작되었습니다")
        } catch {
            print("🔴 오디오 모니터링 시작 오류: \(error.localizedDescription)")
            isMonitoring = false
            hasTapInstalled = false
        }
    }

    func stopAudioMonitoring() {
        if !isMonitoring {
            return // 이미 모니터링 중이 아님
        }

        print("오디오 레벨 모니터링 중지...")

        // 오디오 탭 제거
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }

        // 녹음 중이 아닐 때만 오디오 엔진 중지
        if !isRecording && audioEngine.isRunning {
            audioEngine.stop()
        }

        isMonitoring = false
        print("✅ 오디오 레벨 모니터링이 중지되었습니다")
    }

    func startRecording(to _: URL) {
        print("\n===== 녹음 시작 시도 =====")

        if isRecording {
            print("이미 녹음 중입니다. 기존 녹음을 중지합니다.")
            stopRecording()
        }

        // 임시 파일 경로 생성
        let tempURL = TempFileManager.shared.createTempAudioFilePath()
        currentRecordingURL = tempURL
        print("임시 녹음 파일 경로: \(tempURL.path)")

        // 오디오 라우팅 검증
        if !verifyAudioRouting() {
            print("⚠️ 오디오 라우팅이 올바르게 설정되지 않았습니다")

            // 사용자에게 알림 표시 코드는 여기에 추가
            // 그러나 녹음은 진행할 수 있도록 합니다 (디버깅 목적)
            print("경고가 있지만 녹음을 계속 진행합니다...")
        }

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
            AVLinearPCMIsNonInterleaved: false,
        ]

        print("녹음 설정: \(settings)")

        do {
            audioFile = try AVAudioFile(forWriting: tempURL, settings: settings)
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
                        &propertySize
                    )

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
                        } else {
                            // 파일 크기가 충분하면 서버로 업로드
                            print("녹음된 파일을 서버로 업로드합니다...")
                            uploadRecordingToServer(url: url)
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

    private func uploadRecordingToServer(url: URL) {
        SummaryManager.shared.uploadAudioFile(fileURL: url)
    }

    // changeAudioDevice() 메서드 수정
    func changeAudioDevice(deviceID: AudioDeviceID) {
        print("\n----- 오디오 장치 변경 시작 -----")
        print("새 장치 ID: \(deviceID)")

        // 이미 변경 작업 중인지 확인 (락 메커니즘)
        if isChangingDevice {
            print("⚠️ 장치 변경이 이미 진행 중입니다. 요청을 무시합니다.")
            return
        }

        isChangingDevice = true

        // 장치 이름 로깅
        if let deviceName = getDeviceName(deviceID: deviceID) {
            print("선택된 장치: \(deviceName)")
        }

        // 현재 녹음 중이면 중지
        let wasRecording = isRecording
        let currentURL = currentRecordingURL

        // 모니터링 중이면
        let wasMonitoring = isMonitoring
        if wasMonitoring {
            stopAudioMonitoring()
        }

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
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }

        // 시스템 기본 입력 장치 변경
        do {
            // 새 장치로 변경
            var newDeviceID = deviceID
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &newDeviceID
            )

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

            // 장치 변경 후 충분한 지연을 줌
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }

                // 이전에 모니터링 중이었다면 모니터링 재개
                if wasMonitoring && !wasRecording {
                    self.startAudioMonitoring()
                }

                // 이전에 녹음 중이었다면 녹음 재개
                if wasRecording, let url = currentURL {
                    print("이전 녹음을 재개합니다: \(url.path)")
                    self.startRecording(to: url)
                }

                print("✅ 오디오 장치 변경 완료")
                self.isChangingDevice = false
            }
        } catch {
            print("🔴 오디오 장치 변경 오류: \(error)")
            isChangingDevice = false
        }

        print("----- 오디오 장치 변경 완료 -----\n")
    }

    private func logCurrentAudioDevices() {
        print("\n----- 현재 시스템 오디오 설정 -----")

        // 기본 입력 장치 확인
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var inputDeviceID: AudioDeviceID = 0
        let status1 = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &inputDeviceID
        )

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
            &outputDeviceID
        )

        if status2 == noErr, let outputName = getDeviceName(deviceID: outputDeviceID) {
            print("기본 출력 장치: \(outputName) (ID: \(outputDeviceID))")
        } else {
            print("기본 출력 장치를 확인할 수 없습니다")
        }

        // 현재 선택된 장치 정보
        if let selectedID = selectedDeviceID,
           let selectedName = getDeviceName(deviceID: selectedID)
        {
            print("현재 선택된 장치: \(selectedName) (ID: \(selectedID))")
        } else {
            print("현재 선택된 장치 없음")
        }

        print("------------------------------\n")
    }

    private func performDeviceChange(deviceID: AudioDeviceID, wasRecording: Bool, recordingURL: URL?) {
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
            print("ℹ️ 입력 노드에 설치된 탭이 없습니다")
        }

        // 시스템 기본 입력 장치 변경
        do {
            // 새 장치로 변경
            var newDeviceID = deviceID
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &newDeviceID
            )

            if status != noErr {
                print("⚠️ 입력 장치를 변경하는 데 실패했습니다 (오류 코드: \(status))")
            } else {
                print("✅ 시스템 입력 장치가 변경되었습니다")
            }

            // 장치 변경 후 충분한 지연을 줌 (시스템이 안정화되도록)
            Thread.sleep(forTimeInterval: 1.0)

            // 오디오 엔진 재설정
            print("오디오 엔진 재설정 중...")
            setupAudioEngine()

            // 오디오 라우팅 검증 (충분한 지연 후)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }

                if self.verifyAudioRouting() {
                    print("✅ 오디오 라우팅이 올바르게 설정되었습니다")
                }

                self.selectedDeviceID = deviceID

                // 이전에 녹음 중이었다면 녹음 재개 (약간의 지연 후)
                if wasRecording, let url = recordingURL {
                    print("이전 녹음을 재개합니다: \(url.path)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.startRecording(to: url)
                    }
                }

                print("✅ 오디오 장치 변경 완료")
                self.isChangingDevice = false
            }
        } catch {
            print("🔴 오디오 장치 변경 오류: \(error)")
            isChangingDevice = false
        }

        print("----- 오디오 장치 변경 진행 중 -----")
    }

    private var deviceChangePropertyAddress: AudioObjectPropertyAddress = .init(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var defaultOutputChangePropertyAddress: AudioObjectPropertyAddress = .init(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var defaultInputChangePropertyAddress: AudioObjectPropertyAddress = .init(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    // 오디오 장치 변경 리스너 등록
    func setupAudioRouteChangeListener() {
        // 장치 리스트 변경 리스너
        var status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceChangePropertyAddress,
            deviceListChangeListener,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status != noErr {
            print("⚠️ 오디오 장치 변경 리스너 등록 실패: \(status)")
        }

        // 기본 출력 장치 변경 리스너
        status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputChangePropertyAddress,
            defaultDeviceChangeListener,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status != noErr {
            print("⚠️ 기본 출력 장치 변경 리스너 등록 실패: \(status)")
        }

        // 기본 입력 장치 변경 리스너
        status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputChangePropertyAddress,
            defaultDeviceChangeListener,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status != noErr {
            print("⚠️ 기본 입력 장치 변경 리스너 등록 실패: \(status)")
        }
    }

    // 콜백 함수 정의
    let deviceListChangeCallback: AudioObjectPropertyListenerProc = { _, _, _, inClientData in
        // 비동기 작업은 별도로 디스패치하고, 함수 자체는 바로 noErr을 반환합니다
        DispatchQueue.main.async {
            if let context = inClientData {
                let manager = Unmanaged<AudioCaptureManager>.fromOpaque(context).takeUnretainedValue()
                print("🔔 시스템 오디오 장치 목록이 변경되었습니다")
                manager.loadAudioDevices()
            }
        }
        // 함수 자체는 OSStatus를 즉시 반환
        return noErr
    }

    // 오디오 라우팅 변경 콜백 함수 - 정확한 시그니처 사용
    private let deviceListChangeListener: AudioObjectPropertyListenerProc = { _, _, _, clientData in
        DispatchQueue.main.async {
            if let context = clientData {
                let manager = Unmanaged<AudioCaptureManager>.fromOpaque(context).takeUnretainedValue()
                print("🔔 시스템 오디오 장치 목록이 변경되었습니다")
                manager.loadAudioDevices()
            }
        }
        return noErr
    }

    private let defaultDeviceChangeListener: AudioObjectPropertyListenerProc = { _, _, properties, clientData in
        DispatchQueue.main.async {
            guard let context = clientData else { return }
            let manager = Unmanaged<AudioCaptureManager>.fromOpaque(context).takeUnretainedValue()

            // 매개변수 이름 수정 - properties는 UnsafePointer<AudioObjectPropertyAddress> 타입
            let propertyAddress = properties.pointee

            // 입력 장치 변경 감지
            if propertyAddress.mSelector == kAudioHardwarePropertyDefaultInputDevice {
                print("🔔 시스템 기본 입력 장치가 변경되었습니다")

                // 새로운 기본 입력 장치 정보 가져오기
                var deviceID: AudioDeviceID = 0
                var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDefaultInputDevice,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )

                let status = AudioObjectGetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &address,
                    0,
                    nil,
                    &propertySize,
                    &deviceID
                )

                if status == noErr,
                   let deviceName = manager.getDeviceName(deviceID: deviceID),
                   manager.selectedDeviceID != deviceID
                {
                    print("새 기본 입력 장치: \(deviceName) (ID: \(deviceID))")

                    // 앱의 선택된 디바이스도 업데이트
                    if manager.isRecording {
                        print("⚠️ 녹음 중에 시스템에서 입력 장치가 변경되었습니다. 장치를 업데이트합니다.")
                    }
                    manager.handleExternalDeviceChange(deviceID: deviceID)
                }
            }

            // 출력 장치 변경 감지
            if propertyAddress.mSelector == kAudioHardwarePropertyDefaultOutputDevice {
                print("🔔 시스템 기본 출력 장치가 변경되었습니다")

                // 현재 BlackHole을 사용 중인 경우 경고
                if manager.isRecording {
                    var deviceID: AudioDeviceID = 0
                    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
                    var address = AudioObjectPropertyAddress(
                        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain
                    )

                    let status = AudioObjectGetPropertyData(
                        AudioObjectID(kAudioObjectSystemObject),
                        &address,
                        0,
                        nil,
                        &propertySize,
                        &deviceID
                    )

                    if status == noErr, let deviceName = manager.getDeviceName(deviceID: deviceID) {
                        print("새 기본 출력 장치: \(deviceName)")

                        if !deviceName.contains("BlackHole") {
                            print("⚠️ 녹음 중에 출력 장치가 BlackHole에서 다른 장치로 변경되었습니다. 시스템 오디오 캡처가 중단될 수 있습니다.")
                            manager.notifyOutputDeviceChanged()
                        }
                    }
                }

                // 오디오 라우팅 검증
                manager.verifyAudioRouting()
            }
        }
        return noErr
    }

    // 외부에서 장치 변경을 처리하는 함수
    func handleExternalDeviceChange(deviceID: AudioDeviceID) {
        // 녹음 중이 아니거나 장치 변경 중이 아닐 때만 즉시 변경
        if !isChangingDevice && !isRecording {
            selectedDeviceID = deviceID
            setupAudioEngine()
            print("✅ 시스템 입력 장치 변경에 맞춰 앱 설정이 업데이트되었습니다")
        } else if !isChangingDevice {
            // 녹음 중이면 사용자에게 알림 표시
            print("⚠️ 녹음 중 시스템 입력 장치가 변경되었습니다. 변경사항을 적용하려면 녹음을 중지한 후 다시 시작하세요.")
            notifyInputDeviceChanged()
        }
    }

    // 사용자에게 장치 변경 알림 (UI 알림을 표시하는 코드)
    func notifyInputDeviceChanged() {
        // NotificationCenter를 통해 UI에 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioInputDeviceChanged"),
            object: nil
        )
    }

    func notifyOutputDeviceChanged() {
        // NotificationCenter를 통해 UI에 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioOutputDeviceChanged"),
            object: nil
        )
    }

    func verifyAudioRouting() -> Bool {
        print("\n----- 오디오 라우팅 검증 -----")
        var isRoutingCorrect = true

        // 1. 선택된 입력 장치가 BlackHole인지 확인
        if let selectedID = selectedDeviceID,
           let inputName = getDeviceName(deviceID: selectedID)
        {
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
            mElement: kAudioObjectPropertyElementMain
        )

        var outputDeviceID: AudioDeviceID = 0
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &outputDeviceID
        )

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
                &propertySize
            )

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
        for i in 0 ..< Int(buffer.frameLength) {
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

    // 현재 녹음 파일 URL 반환
    func getCurrentRecordingURL() -> URL? {
        return currentRecordingURL
    }
}
