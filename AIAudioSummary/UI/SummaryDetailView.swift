//
//  SummaryDetailView.swift
//  AIAudioSummary
//
//  Created by primadonna on 3/01/25.
//

import SwiftUI

struct SummaryDetailView: View {
    let summary: SummaryResponse
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var settings = AppSettings()
    private var theme: SolarizedTheme {
        return SolarizedColors.themeWith(settings: settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더
                HStack {
                    Text(summary.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(theme.highlight)

                    Spacer()

                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(theme.dimText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 8)

                // 메타 정보
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(summary.audioFileName, systemImage: "waveform")
                            .font(.system(size: 14))

                        Spacer()

                        Text(summary.formattedDuration)
                            .font(.system(size: 14, design: .monospaced))
                    }
                    .foregroundColor(theme.foreground)

                    Text("작성일: \(summary.formattedDate)")
                        .font(.system(size: 14))
                        .foregroundColor(theme.dimText)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.secondaryBg.opacity(0.7))
                )

                // 키워드 섹션
                if !summary.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("키워드")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.highlight)

                        FlowLayout(spacing: 8) {
                            ForEach(summary.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.highlight)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(theme.highlight.opacity(0.15))
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }

                // 요약 내용
                VStack(alignment: .leading, spacing: 10) {
                    Text("요약")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.highlight)

                    Text(summary.summary)
                        .font(.system(size: 15))
                        .foregroundColor(theme.brightText)
                        .lineSpacing(6)
                }

                Spacer()
            }
            .padding(24)
        }
        .background(theme.backgroundGradient.ignoresSafeArea())
    }
}

// 유동적인 레이아웃을 위한 FlowLayout 구현
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0

        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)

            if x + viewSize.width > width {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }

            maxHeight = max(maxHeight, viewSize.height)
            x += viewSize.width + spacing
        }

        height = y + maxHeight

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0

        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)

            if x + viewSize.width > bounds.maxX {
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }

            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: viewSize.width, height: viewSize.height))

            maxHeight = max(maxHeight, viewSize.height)
            x += viewSize.width + spacing
        }
    }
}
