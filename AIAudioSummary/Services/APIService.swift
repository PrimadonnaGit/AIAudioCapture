//
//  APIService.swift
//  AIAudioSummary
//
//  Created by primadonna on 3/01/25.
//

import Combine
import Foundation

struct SummaryResponse: Codable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let keywords: [String]
    let createdAt: String
    let audioFileName: String
    let audioDuration: Double

    var formattedDuration: String {
        let minutes = Int(audioDuration) / 60
        let seconds = Int(audioDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        if let date = formatter.date(from: createdAt) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
            return outputFormatter.string(from: date)
        }
        return createdAt
    }
}

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(String)

    var message: String {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case let .requestFailed(error):
            return "요청 실패: \(error.localizedDescription)"
        case .invalidResponse:
            return "유효하지 않은 응답입니다."
        case let .decodingFailed(error):
            return "데이터 디코딩 실패: \(error.localizedDescription)"
        case let .serverError(message):
            return "서버 오류: \(message)"
        }
    }
}

class APIService {
    static let shared = APIService()

    private let baseURL = "http://localhost:8000"
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // 오디오 파일 업로드
    func uploadAudio(fileURL: URL, completion: @escaping (Result<SummaryResponse, APIError>) -> Void) {
        // 파일이 실제로 존재하는지 확인
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            completion(.failure(.invalidURL))
            return
        }

        // 요청 URL
        guard let url = URL(string: "\(baseURL)/upload") else {
            completion(.failure(.invalidURL))
            return
        }

        // 멀티파트 폼 데이터 경계 생성
        let boundary = UUID().uuidString

        // 요청 생성
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // 파일 데이터 가져오기
        do {
            let data = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent

            // 멀티파트 폼 데이터 생성
            var body = Data()

            // 파일 부분 추가
            body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            // 요청 바디 설정
            request.httpBody = body

            // 업로드 진행 로그
            print("업로드 시작: \(fileName), 파일 크기: \(data.count) 바이트")

            // 요청 실행
            URLSession.shared.dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: SummaryResponse.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { result in
                    switch result {
                    case .finished:
                        break
                    case let .failure(error):
                        if let urlError = error as? URLError {
                            completion(.failure(.requestFailed(urlError)))
                        } else if let decodingError = error as? DecodingError {
                            completion(.failure(.decodingFailed(decodingError)))
                        } else {
                            completion(.failure(.requestFailed(error)))
                        }
                    }
                }, receiveValue: { response in
                    completion(.success(response))
                })
                .store(in: &cancellables)

        } catch {
            completion(.failure(.requestFailed(error)))
        }
    }

    // 요약 목록 가져오기
    func fetchSummaries(completion: @escaping (Result<[SummaryResponse], APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/summaries") else {
            completion(.failure(.invalidURL))
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [SummaryResponse].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    break
                case let .failure(error):
                    if let urlError = error as? URLError {
                        completion(.failure(.requestFailed(urlError)))
                    } else if let decodingError = error as? DecodingError {
                        completion(.failure(.decodingFailed(decodingError)))
                    } else {
                        completion(.failure(.requestFailed(error)))
                    }
                }
            }, receiveValue: { response in
                completion(.success(response))
            })
            .store(in: &cancellables)
    }

    // 특정 요약 가져오기
    func fetchSummary(id: String, completion: @escaping (Result<SummaryResponse, APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/summaries/\(id)") else {
            completion(.failure(.invalidURL))
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: SummaryResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    break
                case let .failure(error):
                    if let urlError = error as? URLError {
                        completion(.failure(.requestFailed(urlError)))
                    } else if let decodingError = error as? DecodingError {
                        completion(.failure(.decodingFailed(decodingError)))
                    } else {
                        completion(.failure(.requestFailed(error)))
                    }
                }
            }, receiveValue: { response in
                completion(.success(response))
            })
            .store(in: &cancellables)
    }

    // 서버 상태 확인
    func checkServerStatus(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(false)
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .map { data -> Bool in
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let status = json["status"] as? String,
                       status == "online"
                    {
                        return true
                    }
                    return false
                } catch {
                    return false
                }
            }
            .replaceError(with: false)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { isOnline in
                completion(isOnline)
            })
            .store(in: &cancellables)
    }
}
