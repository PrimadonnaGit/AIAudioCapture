//
//  SummaryListView.swift
//  AIAudioSummary
//
//  Created by primadonna on 3/01/25.
//

import SwiftUI

struct SummaryListView: View {
    @ObservedObject var summaryManager = SummaryManager.shared
    @State private var selectedSummaryId: String?
    @State private var showingSummaryDetail = false
    @State private var hasAppeared = false // 뷰가 이미 나타났는지 추적

    // 테마 참조
    @ObservedObject var settings = AppSettings()
    private var theme: SolarizedTheme {
        return SolarizedColors.themeWith(settings: settings)
    }

    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HStack {
                Text("오디오 요약 목록")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.highlight)

                Spacer()

                // 서버 상태 표시
                HStack(spacing: 6) {
                    Circle()
                        .fill(summaryManager.isServerAvailable ? theme.success : theme.danger)
                        .frame(width: 8, height: 8)

                    Text(summaryManager.isServerAvailable ? "서버 연결됨" : "서버 오프라인")
                        .font(.system(size: 12))
                        .foregroundColor(theme.dimText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.secondaryBg.opacity(0.5))
                )

                // 새로고침 버튼
                Button(action: {
                    summaryManager.loadSummaries()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(theme.brightText)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(summaryManager.isLoading)
            }
            .padding(.bottom, 8)

            if summaryManager.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding()

                    Text("처리 중...")
                        .font(.system(size: 14))
                        .foregroundColor(theme.dimText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = summaryManager.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(theme.warning)

                    Text("오류 발생")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.brightText)

                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(theme.dimText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if summaryManager.summaries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(theme.dimText)

                    Text(summaryManager.isServerAvailable ? "요약이 없습니다" : "서버에 연결할 수 없습니다")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.brightText)

                    Text(summaryManager.isServerAvailable ?
                        "녹음을 완료하면 자동으로 요약이 생성됩니다" :
                        "서버 연결을 확인해주세요")
                        .font(.system(size: 14))
                        .foregroundColor(theme.dimText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 요약 목록
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(summaryManager.summaries) { summary in
                            SummaryCard(summary: summary)
                                .onTapGesture {
                                    selectedSummaryId = summary.id
                                    showingSummaryDetail = true
                                }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .padding(20)
        .background(theme.cardBg)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8)
        .padding()
        .sheet(isPresented: $showingSummaryDetail) {
            if let summaryId = selectedSummaryId,
               let summary = summaryManager.summaries.first(where: { $0.id == summaryId })
            {
                SummaryDetailView(summary: summary)
            }
        }
        .onAppear {
            // 처음 나타날 때만 서버 상태 및 요약 로드
            if !hasAppeared {
                if !summaryManager.isServerAvailable {
                    summaryManager.checkServerStatus()
                }
                hasAppeared = true
            }
        }
    }
}

struct SummaryCard: View {
    let summary: SummaryResponse

    @ObservedObject var settings = AppSettings()
    private var theme: SolarizedTheme {
        return SolarizedColors.themeWith(settings: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.brightText)
                    .lineLimit(1)

                Spacer()

                Text(summary.formattedDate)
                    .font(.system(size: 12))
                    .foregroundColor(theme.dimText)
            }

            Text(summary.summary)
                .font(.system(size: 14))
                .foregroundColor(theme.foreground)
                .lineLimit(2)
                .padding(.bottom, 4)

            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundColor(theme.highlight.opacity(0.8))

                Text(summary.audioFileName)
                    .font(.system(size: 12))
                    .foregroundColor(theme.dimText)

                Spacer()

                Text(summary.formattedDuration)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.dimText)
            }

            // 키워드 태그
            if !summary.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(summary.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.system(size: 11))
                                .foregroundColor(theme.highlight)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(theme.highlight.opacity(0.15))
                                )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.secondaryBg))
    }
}
