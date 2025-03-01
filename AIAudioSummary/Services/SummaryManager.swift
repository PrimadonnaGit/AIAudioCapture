//
//  SummaryManager.swift
//  AIAudioSummary
//
//  Created by primadonna on 3/01/25.
//

import Combine
import Foundation

class SummaryManager: ObservableObject {
    static let shared = SummaryManager()

    @Published var summaries: [SummaryResponse] = []
    @Published var currentSummary: SummaryResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isServerAvailable = false

    private var cancellables = Set<AnyCancellable>()
    private var pollingTask: DispatchWorkItem?

    private init() {
        checkServerStatus()
    }

    func checkServerStatus() {
        APIService.shared.checkServerStatus { [weak self] isAvailable in
            self?.isServerAvailable = isAvailable
            if isAvailable {
                // 서버가 사용 가능할 때만 요약 목록 로드
                self?.loadSummaries()
            }
        }
    }

    func loadSummaries() {
        // 이미 로딩 중이면 중복 호출 방지
        if isLoading { return }

        isLoading = true
        errorMessage = nil

        print("요약 목록 로드 시작...")

        APIService.shared.fetchSummaries { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case let .success(summaries):
                self.summaries = summaries.sorted { $0.createdAt > $1.createdAt }
                print("요약 \(summaries.count)개 로드 완료")
            case let .failure(error):
                self.errorMessage = error.message
                print("요약 로드 실패: \(error.message)")
            }
        }
    }

    func uploadAudioFile(fileURL: URL) {
        isLoading = true
        errorMessage = nil

        print("오디오 파일 업로드 시작: \(fileURL.lastPathComponent)")

        APIService.shared.uploadAudio(fileURL: fileURL) { [weak self] result in
            switch result {
            case let .success(summary):
                print("오디오 업로드 성공: \(summary.id)")
                self?.currentSummary = summary

                // 요약 생성이 완료되지 않은 경우에만 폴링 시작
                if summary.title.contains("Processing") || summary.summary.contains("processing") {
                    self?.startPollingForCompletion(summaryId: summary.id)
                } else {
                    // 이미 처리가 완료된 경우
                    self?.isLoading = false
                    // 새 요약이 추가되었으므로 목록 업데이트
                    self?.loadSummaries()
                }

            case let .failure(error):
                self?.isLoading = false
                self?.errorMessage = error.message
                print("오디오 업로드 실패: \(error.message)")
            }
        }
    }

    // 요약 처리 완료 상태를 확인하는 폴링 로직
    private func startPollingForCompletion(summaryId: String) {
        // 이전 폴링 작업이 있다면 취소
        pollingTask?.cancel()

        print("요약 처리 상태 확인 시작: \(summaryId)")

        // 최대 10회, 5초 간격으로 폴링 (최대 50초)
        var remainingPolls = 10

        func poll() {
            let task = DispatchWorkItem { [weak self] in
                guard let self = self, remainingPolls > 0 else { return }
                remainingPolls -= 1

                self.checkSummaryStatus(summaryId: summaryId) { isComplete in
                    if isComplete {
                        print("요약 처리 완료됨")
                        // 처리 완료 - 폴링 중단
                        self.isLoading = false
                        self.loadSummaries() // 완료 시에만 목록 새로고침
                    } else if remainingPolls > 0 {
                        // 아직 처리 중 - 5초 후 다시 확인
                        print("요약 처리 중... 남은 확인 횟수: \(remainingPolls)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            poll()
                        }
                    } else {
                        // 최대 시도 횟수 초과
                        print("요약 처리 대기 시간 초과")
                        self.isLoading = false
                        self.errorMessage = "요약 처리 시간이 너무 오래 걸립니다. 나중에 다시 확인해주세요."
                    }
                }
            }

            pollingTask = task
            DispatchQueue.main.async(execute: task)
        }

        // 폴링 시작
        poll()
    }

    // 단일 요약 상태 확인
    private func checkSummaryStatus(summaryId: String, completion: @escaping (Bool) -> Void) {
        APIService.shared.fetchSummary(id: summaryId) { [weak self] result in
            switch result {
            case let .success(summary):
                self?.currentSummary = summary

                // 처리 중이 아닌 경우 완료로 간주
                let isComplete = !summary.title.contains("Processing") && !summary.summary.contains("processing")
                completion(isComplete)

            case let .failure(error):
                print("요약 상태 확인 실패: \(error.message)")
                self?.isLoading = false
                completion(false)
            }
        }
    }

    // 앱이 백그라운드로 가거나 종료될 때 폴링 정리
    func cleanup() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
