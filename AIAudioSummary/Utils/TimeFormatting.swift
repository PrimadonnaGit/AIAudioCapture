//
//  TimeFormatting.swift
//  AIAudioSummary
//
//  Created by primadonna on 2/28/25.
//

import Foundation

extension DateFormatter {
    static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
