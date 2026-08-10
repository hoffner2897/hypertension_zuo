import Foundation
import SwiftUI

enum ExerciseTimeRange {
    static let startOptions: [String] = stride(from: 0, to: 24 * 60, by: 30).map(timeText)

    static func durationMinutes(from startTime: String, to endTime: String) -> Int {
        guard let start = minutes(for: startTime),
              let end = minutes(for: endTime),
              end > start else {
            return 5
        }
        return end - start
    }

    static func endTime(startTime: String, durationMinutes: Int) -> String {
        guard let start = minutes(for: startTime) else { return "00:05" }
        let end = min(start + max(durationMinutes, 5), 23 * 60 + 55)
        return timeText(end)
    }

    static func endOptions(after startTime: String, including preferredEndTime: String? = nil) -> [String] {
        guard let start = minutes(for: startTime) else { return [] }
        let finalMinute = min(start + 180, 23 * 60 + 55)
        var values: [String] = []

        if finalMinute >= start + 5 {
            values = stride(from: start + 5, through: finalMinute, by: 5).map(timeText)
        }

        if let preferredEndTime,
           let preferred = minutes(for: preferredEndTime),
           preferred > start,
           !values.contains(preferredEndTime) {
            values.append(preferredEndTime)
            values.sort { (minutes(for: $0) ?? 0) < (minutes(for: $1) ?? 0) }
        }

        return values
    }

    static func normalizedEndTime(
        startTime: String,
        currentEndTime: String,
        fallbackDurationMinutes: Int = 30
    ) -> String {
        guard let start = minutes(for: startTime),
              let currentEnd = minutes(for: currentEndTime),
              currentEnd > start else {
            return endTime(startTime: startTime, durationMinutes: fallbackDurationMinutes)
        }
        return currentEndTime
    }

    private static func minutes(for value: String) -> Int? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              (0..<24).contains(parts[0]),
              (0..<60).contains(parts[1]) else {
            return nil
        }
        return parts[0] * 60 + parts[1]
    }

    private static func timeText(_ totalMinutes: Int) -> String {
        String(format: "%02d:%02d", totalMinutes / 60, totalMinutes % 60)
    }
}

struct ExerciseTimeRangePicker: View {
    @Binding var startTime: String
    @Binding var endTime: String
    var isLocked = false

    var body: some View {
        HStack(alignment: .top, spacing: DSTheme.Spacing.small) {
            timeField(
                title: "开始时间",
                value: startTime,
                options: ExerciseTimeRange.startOptions
            ) { newStartTime in
                let preservedDuration = ExerciseTimeRange.durationMinutes(
                    from: startTime,
                    to: endTime
                )
                startTime = newStartTime
                endTime = ExerciseTimeRange.endTime(
                    startTime: newStartTime,
                    durationMinutes: preservedDuration
                )
            }

            timeField(
                title: "结束时间",
                value: endTime,
                options: ExerciseTimeRange.endOptions(
                    after: startTime,
                    including: endTime
                )
            ) { endTime = $0 }
        }
        .onAppear {
            endTime = ExerciseTimeRange.normalizedEndTime(
                startTime: startTime,
                currentEndTime: endTime
            )
        }
    }

    private func timeField(
        title: String,
        value: String,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSTheme.Color.textSecondary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { onSelect(option) }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(DSTheme.Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DSTheme.Color.primary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DSTheme.Color.border, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
        }
        .frame(maxWidth: .infinity)
    }
}
