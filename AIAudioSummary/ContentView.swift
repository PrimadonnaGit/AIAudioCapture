import SwiftUI
import Combine
import AVFoundation

// 앱 설정을 관리하는 클래스
class AppSettings: ObservableObject {
    @Published var uiOpacity: Double {
        didSet {
            UserDefaults.standard.set(uiOpacity, forKey: "uiOpacity")
        }
    }
    
    @Published var backgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity")
        }
    }
    
    @Published var accentColorIndex: Int {
        didSet {
            UserDefaults.standard.set(accentColorIndex, forKey: "accentColorIndex")
        }
    }
    
    // 액센트 색상 옵션
    let accentColorOptions = [
        ("청록", Color(hex: "2aa198")),  // 기본 Solarized 청록
        ("파랑", Color(hex: "268bd2")),  // Solarized 파랑
        ("녹색", Color(hex: "859900")),  // Solarized 녹색
        ("보라", Color(hex: "6c71c4")),  // Solarized 보라
        ("자주", Color(hex: "d33682")),  // Solarized 자주
        ("노랑", Color(hex: "b58900"))   // Solarized 노랑
    ]
    
    var currentAccentColor: Color {
        return accentColorOptions[accentColorIndex].1
    }
    
    init() {
        // 저장된 설정 로드 또는 기본값 사용
        self.uiOpacity = UserDefaults.standard.object(forKey: "uiOpacity") as? Double ?? 0.85
        self.backgroundOpacity = UserDefaults.standard.object(forKey: "backgroundOpacity") as? Double ?? 0.95
        self.accentColorIndex = UserDefaults.standard.object(forKey: "accentColorIndex") as? Int ?? 0
    }
    
    // 모든 설정을 기본값으로 재설정
    func resetToDefaults() {
        uiOpacity = 0.85
        backgroundOpacity = 0.95
        accentColorIndex = 0
    }
}

// 부드러운 Solarized Dark 테마 색상 구조체
struct SolarizedColors {
    // 앱 설정을 참조하여 색상 불러오기
    static func themeWith(settings: AppSettings) -> SolarizedTheme {
        return SolarizedTheme(settings: settings)
    }
    
    // 기본 색상 값 (설정 참조 없음)
    static let base03 = Color(hex: "002b36")        // 기본 배경
    static let base02 = Color(hex: "073642")        // 컨트롤 배경
    static let base01 = Color(hex: "586e75")        // 흐린 텍스트
    static let base00 = Color(hex: "657b83")        // 중간 텍스트
    static let base0 = Color(hex: "839496")         // 기본 텍스트
    static let base1 = Color(hex: "93a1a1")         // 밝은 텍스트
    static let base2 = Color(hex: "eee8d5").opacity(0.1) // 강조 배경
    static let base3 = Color(hex: "fdf6e3").opacity(0.05) // 가장 밝은 배경
    
    static let yellow = Color(hex: "b58900")        // 노란색 강조
    static let orange = Color(hex: "cb4b16")        // 경고색 (주황)
    static let red = Color(hex: "dc322f")           // 주의색 (빨강)
    static let magenta = Color(hex: "d33682")       // 자주색
    static let violet = Color(hex: "6c71c4")        // 보라색
    static let blue = Color(hex: "268bd2")          // 파랑색
    static let cyan = Color(hex: "2aa198")          // 청록색
    static let green = Color(hex: "859900")         // 녹색
}

// 앱 설정에 따라 변경되는 테마 구조체
struct SolarizedTheme {
    let settings: AppSettings
    
    // 배경 색상
    var background: Color {
        return SolarizedColors.base03.opacity(settings.backgroundOpacity)
    }
    
    var secondaryBg: Color {
        return SolarizedColors.base02.opacity(settings.uiOpacity)
    }
    
    var foreground: Color {
        return SolarizedColors.base0.opacity(min(settings.uiOpacity + 0.1, 1.0))
    }
    
    // 설정에서 선택한 액센트 색상
    var highlight: Color {
        return settings.currentAccentColor.opacity(settings.uiOpacity)
    }
    
    var warning: Color {
        return SolarizedColors.orange.opacity(settings.uiOpacity + 0.05)
    }
    
    var danger: Color {
        return SolarizedColors.red.opacity(settings.uiOpacity + 0.05)
    }
    
    var success: Color {
        return SolarizedColors.green.opacity(settings.uiOpacity)
    }
    
    var accent: Color {
        return SolarizedColors.blue.opacity(settings.uiOpacity)
    }
    
    var yellow: Color {
        return SolarizedColors.yellow.opacity(settings.uiOpacity)
    }
    
    var purple: Color {
        return SolarizedColors.violet.opacity(settings.uiOpacity - 0.05)
    }
    
    var magenta: Color {
        return SolarizedColors.magenta.opacity(settings.uiOpacity - 0.05)
    }
    
    var brightText: Color {
        return SolarizedColors.base1.opacity(min(settings.uiOpacity + 0.1, 1.0))
    }
    
    var dimText: Color {
        return SolarizedColors.base01.opacity(settings.uiOpacity)
    }
    
    var cardBg: Color {
        return SolarizedColors.base02.opacity(settings.uiOpacity - 0.15)
    }
    
    // 버튼 배경용 gradient
    func buttonGradient(_ color: Color) -> LinearGradient {
        let baseOpacity = settings.uiOpacity
        return LinearGradient(
            gradient: Gradient(colors: [
                color.opacity(baseOpacity),
                color.opacity(baseOpacity - 0.1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // 배경 그라데이션
    var backgroundGradient: LinearGradient {
        return LinearGradient(
            gradient: Gradient(colors: [
                background,
                Color(hex: "00252e").opacity(settings.backgroundOpacity - 0.05)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// HEX 코드로부터 Color 생성을 위한 확장
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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
    private let fixedWidth: CGFloat = 600
    private let fixedHeight: CGFloat = 680
    
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
                recordingStatusView
                controlButtonsView
                
                // 디버그 모드일 때만 로그 표시
                if isDebugMode {
                    logView
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
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingDeviceSelector) {
            deviceSelectorView
                .frame(width: 480)  // 너비만 고정하고 높이는 콘텐츠에 맞게 조정
        }
        .sheet(isPresented: $showingSettings) {
            settingsView
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
    
    // 설정 뷰
    private var settingsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 헤더
                Text("설정")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(theme.highlight)
                    .padding(.top, 24)
                
                // 설정 섹션들
                VStack(spacing: 24) {
                    // UI 색상 섹션
                    settingSection(title: "UI 색상") {
                        // 액센트 색상 선택
                        VStack(alignment: .leading, spacing: 10) {
                            Text("액센트 색상")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(theme.foreground)
                            
                            HStack(spacing: 12) {
                                ForEach(0..<settings.accentColorOptions.count, id: \.self) { index in
                                    let (name, color) = settings.accentColorOptions[index]
                                    
                                    Button(action: {
                                        withAnimation {
                                            settings.accentColorIndex = index
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 36, height: 36)
                                            
                                            if settings.accentColorIndex == index {
                                                Circle()
                                                    .strokeBorder(Color.white, lineWidth: 2)
                                                    .frame(width: 36, height: 36)
                                            }
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .overlay(
                                        Text(name)
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.dimText)
                                            .padding(.top, 40)
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.bottom, 8)
                        
                        // UI 투명도 슬라이더
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("UI 투명도")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.foreground)
                                
                                Spacer()
                                
                                Text("\(Int(settings.uiOpacity * 100))%")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.dimText)
                            }
                            
                            HStack {
                                Text("투명")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.dimText)
                                
                                Slider(value: $settings.uiOpacity, in: 0.5...1.0, step: 0.01)
                                    .accentColor(theme.highlight)
                                
                                Text("불투명")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.dimText)
                            }
                        }
                        
                        // 배경 투명도 슬라이더
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("배경 투명도")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.foreground)
                                
                                Spacer()
                                
                                Text("\(Int(settings.backgroundOpacity * 100))%")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.dimText)
                            }
                            
                            HStack {
                                Text("투명")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.dimText)
                                
                                Slider(value: $settings.backgroundOpacity, in: 0.7...1.0, step: 0.01)
                                    .accentColor(theme.highlight)
                                
                                Text("불투명")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.dimText)
                            }
                        }
                    }
                    
                    // 미리보기 섹션
                    settingSection(title: "미리보기") {
                        // 미리보기 카드
                        HStack(spacing: 16) {
                            // 원형 인디케이터
                            Circle()
                                .fill(theme.highlight)
                                .frame(width: 16, height: 16)
                            
                            // 텍스트
                            VStack(alignment: .leading, spacing: 4) {
                                Text("설정 미리보기")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.brightText)
                                
                                Text("현재 설정된 테마 스타일입니다")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.foreground)
                            }
                            
                            Spacer()
                            
                            // 버튼 샘플
                            Button(action: {}) {
                                Text("버튼")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.background)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .fill(theme.buttonGradient(theme.highlight))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.cardBg)
                        )
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                
                Divider()
                    .background(theme.dimText.opacity(0.2))
                    .padding(.vertical, 8)
                
                // 하단 버튼들
                HStack(spacing: 16) {
                    // 기본값으로 재설정 버튼
                    Button(action: {
                        settings.resetToDefaults()
                    }) {
                        Text("기본값으로 재설정")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(theme.dimText)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                Capsule()
                                    .stroke(theme.dimText.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 확인 버튼
                    Button(action: {
                        showingSettings = false
                    }) {
                        Text("확인")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(theme.background)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 24)
                            .background(
                                Capsule()
                                    .fill(theme.buttonGradient(theme.highlight))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 24)
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
    }
    
    // 설정 섹션 헬퍼 함수
    private func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(theme.highlight)
            
            content()
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.secondaryBg)
                )
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
    
    // 장치 선택 시트 뷰
    private var deviceSelectorView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 헤더
                VStack(spacing: 6) {
                    Text("오디오 입력 장치 선택")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.highlight)
                    
                    Text("BlackHole을 선택하여 시스템 오디오를 캡처하세요")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(theme.dimText)
                }
                .padding(.top, 20)
                
                if audioCaptureManager.availableAudioDevices.isEmpty {
                    Text("사용 가능한 오디오 장치가 없습니다")
                        .foregroundColor(theme.dimText)
                        .padding(.vertical, 40)
                } else {
                    // 장치 목록
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(audioCaptureManager.availableAudioDevices, id: \.id) { device in
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
                                    addLogMessage("오디오 장치 변경: \(device.name)")
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
                    
                    Text("※ 시스템 소리를 들으면서 녹음하려면 Loopback 앱 또는 '다중 출력 장치'를 설정하세요")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(theme.yellow)
                        .padding(.top, 4)
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
    
    // 녹음 상태 뷰
    private var recordingStatusView: some View {
        HStack(spacing: 16) {
            // 상태 표시기
            ZStack {
                Circle()
                    .fill(audioCaptureManager.isRecording ? theme.danger : theme.secondaryBg)
                    .frame(width: 16, height: 16)
                
                if audioCaptureManager.isRecording {
                    Circle()
                        .stroke(theme.danger.opacity(0.7), lineWidth: 2)
                        .scaleEffect(animateWave ? 1.5 : 1.0)
                        .opacity(animateWave ? 0 : 1)
                        .frame(width: 16, height: 16)
                        .animation(
                            Animation.easeOut(duration: 1).repeatForever(autoreverses: false),
                            value: animateWave
                        )
                        .onAppear {
                            animateWave = true
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(audioCaptureManager.isRecording ? "녹음 중..." : "대기 중")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(audioCaptureManager.isRecording ? theme.danger : theme.dimText)
                
                if audioCaptureManager.isRecording {
                    Text(timeString(from: recordingTime))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(theme.foreground)
                }
            }
            
            Spacer()
            
            // 현재 녹음 중인 장치 표시
            if audioCaptureManager.isRecording,
               let selectedID = audioCaptureManager.selectedDeviceID,
               let device = audioCaptureManager.availableAudioDevices.first(where: { $0.id == selectedID }) {
                HStack {
                    Image(systemName: getDeviceIcon(name: device.name))
                        .foregroundColor(theme.highlight.opacity(0.9))
                    
                    Text(device.name)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(theme.brightText)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.secondaryBg.opacity(0.7))
                )
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
                    logMessages.removeAll()
                    addLogMessage("로그를 지웠습니다")
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
    
    // 로그 뷰
    private var logView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("활동 로그")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.brightText)
                
                Spacer()
                
                Text("\(logMessages.count)개 항목")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(theme.dimText)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(logMessages) { message in
                        HStack(alignment: .top, spacing: 10) {
                            // 타임스탬프
                            Text(message.timestamp, formatter: logDateFormatter)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(theme.dimText)
                            
                            // 메시지 내용
                            Text(message.text)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(getLogTextColor(message: message.text))
                                .lineLimit(3)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.secondaryBg.opacity(0.4))
                        )
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
            }
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.background.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.secondaryBg.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBg)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        )
    }
    
    // 로그 메시지 색상 선택
    private func getLogTextColor(message: String) -> Color {
        if message.contains("⚠️") {
            return theme.warning.opacity(0.95)
        } else if message.contains("오류") || message.contains("실패") {
            return theme.danger.opacity(0.95)
        } else if message.contains("✅") || message.contains("성공") {
            return theme.success.opacity(0.95)
        } else if message.contains("BlackHole") {
            return theme.highlight.opacity(0.95)
        } else {
            return theme.foreground.opacity(0.95)
        }
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
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var logDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }
}

// 오디오 바 애니메이션 뷰
struct AudioBar: View {
    let index: Int
    let level: Float
    let isRecording: Bool
    let theme: SolarizedTheme
    
    var body: some View {
        let barHeight = calculateHeight()
        
        RoundedRectangle(cornerRadius: 3)
            .fill(barColor)
            .frame(width: 4, height: barHeight)
            .animation(.easeOut(duration: 0.2), value: level)
    }
    
    private func calculateHeight() -> CGFloat {
        if !isRecording {
            return 5
        }
        
        // 인덱스에 따라 다른 높이 생성 (더 자연스러운 파형을 위해)
        let seed = sin(Double(index) * 0.8) * 0.5 + 0.5
        let variation = sin(Date().timeIntervalSince1970 * 3 + Double(index)) * 0.3 + 0.7
        
        let height = CGFloat(level * Float(seed) * Float(variation) * 80) + 5
        return max(height, 5)
    }
    
    private var barColor: Color {
        if !isRecording {
            return theme.secondaryBg.opacity(0.6)
        }
        
        // 레벨에 따른 색상 변화 (더 부드러운 색상)
        if level < 0.3 {
            return theme.highlight.opacity(0.6 + Double(level))
        } else if level < 0.7 {
            return theme.accent.opacity(0.7)
        } else {
            return theme.warning.opacity(0.7)
        }
    }
}

// 로그 메시지 구조체
struct LogMessage: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let text: String
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(audioCaptureManager: AudioCaptureManager())
    }
}

// AudioDeviceID 타입 추가
typealias AudioDeviceID = UInt32
