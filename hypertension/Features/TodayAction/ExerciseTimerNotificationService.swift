import Foundation
import UserNotifications

enum ExerciseTimerNotificationService {
    static func schedule(for item: TodayActionItem, remainingSeconds: Int) async {
        guard remainingSeconds > 0 else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        let content = UNMutableNotificationContent()
        content.title = L10n.string("运动时间到了")
        content.body = L10n.format(
            "%@ 已达到计划时长，请返回确认完成或继续运动。",
            L10n.string(item.title)
        )
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(remainingSeconds, 1)),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier(for: item.id),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func cancel(for id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier(for: id)]
        )
    }

    private static func identifier(for id: UUID) -> String {
        "bphealth.exercise-timer.\(id.uuidString.lowercased())"
    }
}

enum TreeProgressStore {
    static func highestRate(userId: String, date: Date = Date()) -> Double {
        UserDefaults.standard.double(forKey: key(userId: userId, date: date))
    }

    @discardableResult
    static func record(_ rate: Double, userId: String, date: Date = Date()) -> Double {
        let highest = max(highestRate(userId: userId, date: date), min(max(rate, 0), 1))
        UserDefaults.standard.set(highest, forKey: key(userId: userId, date: date))
        return highest
    }

    private static func key(userId: String, date: Date) -> String {
        "bphealth.tree-progress.\(userId).\(ExerciseActionService.dayString(for: date))"
    }
}
