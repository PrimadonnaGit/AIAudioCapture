//
//  TempFileManager.swift
//  AIAudioSummary
//
//  Created by primadonna on 3/01/25.
//

import Foundation
import SwiftUI

class TempFileManager {
    static let shared = TempFileManager()

    private let tempDirectory: URL

    private init() {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AudioRecordings", isDirectory: true)

        // 임시 디렉토리 생성
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // 앱 종료 시 임시 파일 정리를 위한 알림 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanupTempFiles),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // 새 임시 파일 경로 생성
    func createTempAudioFilePath() -> URL {
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).wav"
        return tempDirectory.appendingPathComponent(fileName)
    }

    // 임시 파일 삭제
    func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // 모든 임시 파일 정리
    @objc func cleanupTempFiles() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
            print("임시 파일 정리 완료")
        } catch {
            print("임시 파일 정리 오류: \(error)")
        }
    }
}
