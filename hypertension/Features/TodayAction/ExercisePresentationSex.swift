import SwiftUI

enum ExercisePresentationSex: Equatable, Sendable {
    case female
    case male

    init(profileSex: String?) {
        self = profileSex == "male" ? .male : .female
    }

    var avatarAssetName: String {
        self == .male ? "TodayHeaderAvatarMale" : "TodayHeaderAvatar"
    }
}

private struct ExercisePresentationSexKey: EnvironmentKey {
    static let defaultValue = ExercisePresentationSex.female
}

extension EnvironmentValues {
    var exercisePresentationSex: ExercisePresentationSex {
        get { self[ExercisePresentationSexKey.self] }
        set { self[ExercisePresentationSexKey.self] = newValue }
    }
}
