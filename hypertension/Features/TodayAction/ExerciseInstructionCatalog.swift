import Foundation

struct ExerciseInstructionCopy: Equatable, Sendable {
    let howTo: String
    let intensity: String
}

enum ExerciseInstructionCatalog {
    /// Reviewed wording from the 2026-08-10 low-barrier exercise workbook.
    static let byExerciseID: [String: ExerciseInstructionCopy] = [
        "private-indoor-march-in-place": ExerciseInstructionCopy(
            howTo: """
            步骤：①站直，双脚轮流抬起；②手臂自然前后摆动
            时间：每5分钟一段；休息1分钟
            要点：脚步轻稳；不要跳；膝盖不用抬高
            """,
            intensity: """
            合适：能完整说话；不能轻松唱歌
            过强：只能说几个词；或脚步开始变乱
            调整方法：放慢速度；仍不能完整说话时继续休息
            """
        ),
        "private-indoor-sit-to-stand": ExerciseInstructionCopy(
            howTo: """
            步骤：①坐在稳固座椅中部，双脚踩地；②身体稍向前，慢慢站起；③再慢慢坐下
            时间：每组8–12次；休息1–2分钟
            要点：座椅不能有轮子；必要时扶住扶手
            """,
            intensity: """
            合适：能正常呼吸；站起和坐下时身体不摇晃
            过强：需要憋气；或膝盖疼、无法慢慢坐下
            调整方法：膝盖疼时停止；其他情况减少次数或扶住扶手
            """
        ),
        "private-indoor-wall-push-up": ExerciseInstructionCopy(
            howTo: """
            步骤：①面对墙站约一臂远，双手与肩同高撑墙；②弯曲手肘靠近墙面；③慢慢推回
            时间：每组8–12次；休息1–2分钟
            要点：从头到脚保持一条直线；脚跟不要抬起
            """,
            intensity: """
            合适：能正常呼吸；推回时身体保持稳定
            过强：需要憋气；或腰背弯曲、肩膀疼
            调整方法：肩膀疼时停止；其他情况站近墙面或减少次数
            """
        ),
        "private-indoor-wall-sit": ExerciseInstructionCopy(
            howTo: """
            步骤：①背部贴墙，双脚向前半步；②慢慢下滑到浅蹲；③短暂保持后站起
            时间：保持5–10秒；休息20–30秒
            要点：只蹲到不疼且能顺利站回的位置；不要憋气
            """,
            intensity: """
            合适：能正常呼吸；双腿没有明显发抖
            过强：憋气、头晕、疼痛或双腿明显发抖
            调整方法：立即站起；下次少蹲一些或缩短时间
            """
        ),
        "private-indoor-seated-alternating-knee-lift": ExerciseInstructionCopy(
            howTo: """
            步骤：①坐稳，双脚踩地；②左右轮流抬起膝盖；③慢慢放下
            时间：每5分钟一段；休息1分钟
            要点：上身保持直立；膝盖只抬到舒服的高度
            """,
            intensity: """
            合适：能完整说话；上身没有明显后仰
            过强：只能说几个词；或腰背不舒服
            调整方法：放慢速度；降低抬膝高度
            """
        ),
        "private-indoor-seated-knee-extension": ExerciseInstructionCopy(
            howTo: """
            步骤：①坐稳，双脚踩地；②一条腿慢慢向前伸直；③慢慢放下后换腿
            时间：每侧8–12次；休息1–2分钟
            要点：上身不要后仰；膝盖疼时立即停止
            """,
            intensity: """
            合适：能正常呼吸；小腿能慢慢抬起和放下
            过强：需要后仰借力；或膝盖疼
            调整方法：立即停止；下次少伸一些或减少次数
            """
        ),
        "public-indoor-slow-walk": ExerciseInstructionCopy(
            howTo: """
            步骤：①选择平坦通道，从慢速开始；②自然迈步，手臂轻松摆动
            时间：每5分钟一段；休息1分钟
            要点：看向前方；避开湿滑地面和障碍物
            """,
            intensity: """
            合适：呼吸稍快；仍能完整说话
            过强：无法连续说完一句话；或步伐不稳
            调整方法：放慢速度；必要时停下休息
            """
        ),
        "public-indoor-march-in-place": ExerciseInstructionCopy(
            howTo: """
            步骤：①站直，双脚轮流抬起；②手臂自然摆动
            时间：每5分钟一段；休息1分钟
            要点：选择不挡路的位置；脚步轻稳；不要跳
            """,
            intensity: """
            合适：能完整说话；不能轻松唱歌
            过强：只能说几个词；或脚步开始变乱
            调整方法：放慢速度；必要时停下休息
            """
        ),
        "public-indoor-side-step": ExerciseInstructionCopy(
            howTo: """
            步骤：①左脚向左迈一步，右脚跟着并拢；②再向右重复
            时间：每2–3分钟一段；休息1分钟
            要点：先确认两侧没有障碍；不要交叉双脚或跳跃
            （注：首次练习建议查看动作视频）
            """,
            intensity: """
            合适：呼吸自然；左右移动时身体不摇晃
            过强：脚步变乱；或身体明显摇晃
            调整方法：缩小步幅；放慢速度或扶住稳固支撑
            """
        ),
        "public-indoor-calf-raise": ExerciseInstructionCopy(
            howTo: """
            步骤：①扶住稳固支撑，双脚站稳；②慢慢抬起脚跟；③再慢慢放下
            时间：每组8–12次；休息1–2分钟
            要点：身体保持直立；不要快速弹动
            """,
            intensity: """
            合适：能正常呼吸；抬起和放下时身体不摇晃
            过强：需要憋气；或小腿疼、身体摇晃
            调整方法：立即放下脚跟；休息更久或减少次数
            """
        ),
        "public-indoor-forward-back-tap": ExerciseInstructionCopy(
            howTo: """
            步骤：①右脚向前点地后收回；②右脚向后点地后收回；③再换左脚
            时间：每2–3分钟一段；休息1分钟
            要点：只需轻点地面；身体保持直立；不要跳
            （注：首次练习建议查看动作视频）
            """,
            intensity: """
            合适：呼吸自然；点步时身体不摇晃
            过强：脚步变乱；或身体明显摇晃
            调整方法：缩短点步距离；放慢速度或扶住稳固支撑
            """
        ),
        "public-indoor-supported-side-leg-raise": ExerciseInstructionCopy(
            howTo: """
            步骤：①一手扶墙，身体站直；②一条腿小幅向侧方抬起；③慢慢放下后换腿
            时间：每侧8–12次；休息1–2分钟
            要点：脚尖朝前；上身不要向侧方倾斜
            """,
            intensity: """
            合适：能正常呼吸；抬腿时身体不摇晃
            过强：需要侧身借力；或大腿根部疼
            调整方法：立即停止；下次少抬一些或减少次数
            """
        ),
        "public-outdoor-slow-walk": ExerciseInstructionCopy(
            howTo: """
            步骤：①选择平坦路线，从慢速开始；②自然迈步，手臂轻松摆动
            时间：每5分钟一段；休息1分钟
            要点：看向前方；避开湿滑地面和障碍物
            """,
            intensity: """
            合适：呼吸稍快；仍能完整说话
            过强：无法连续说完一句话；或步伐不稳
            调整方法：立即放慢速度；必要时停下休息
            """
        ),
        "public-outdoor-moderate-brisk-walk": ExerciseInstructionCopy(
            howTo: """
            步骤：①先慢走，再逐渐加快；②保持自然步幅和稳定节奏
            时间：每5分钟一段；休息1分钟
            要点：不要竞速；结束前逐渐放慢
            """,
            intensity: """
            合适：能完整说话；不能轻松唱歌
            过强：说一句话需要多次换气；或步伐不稳
            调整方法：降低速度；必要时停下休息
            """
        ),
        "public-outdoor-side-step": ExerciseInstructionCopy(
            howTo: """
            步骤：①左脚向左迈一步，右脚跟着并拢；②再向右重复
            时间：每2–3分钟一段；休息1分钟
            要点：选择平坦且两侧没有障碍的位置；不要交叉双脚或跳跃
            （注：首次练习建议查看动作视频）
            """,
            intensity: """
            合适：呼吸自然；左右移动时身体不摇晃
            过强：脚步变乱；或身体明显摇晃
            调整方法：缩小步幅；放慢速度或扶住稳固支撑
            """
        ),
        "public-outdoor-step-jack": ExerciseInstructionCopy(
            howTo: """
            步骤：①一只脚向侧方迈开；②收回后换另一只脚；③双臂可自然抬起
            时间：每2–3分钟一段；休息1分钟
            要点：只迈步；不要跳；周围不要有障碍物
            （注：首次练习建议查看动作视频）
            """,
            intensity: """
            合适：能完整说话；脚步和身体保持稳定
            过强：只能说几个词；或脚步开始变乱
            调整方法：放慢速度；暂时不抬手臂或停下休息
            """
        ),
        "public-outdoor-forward-back-tap": ExerciseInstructionCopy(
            howTo: """
            步骤：①右脚向前点地后收回；②右脚向后点地后收回；③再换左脚
            时间：每2–3分钟一段；休息1分钟
            要点：选择平坦位置；只需轻点地面；不要跳
            （注：首次练习建议查看动作视频）
            """,
            intensity: """
            合适：呼吸自然；点步时身体不摇晃
            过强：脚步变乱；或身体明显摇晃
            调整方法：缩短点步距离；放慢速度或扶住稳固支撑
            """
        ),
        "public-outdoor-low-step-up": ExerciseInstructionCopy(
            howTo: """
            步骤：①一只脚踏上台阶，另一只脚跟上；②第一只脚先踏下，另一只脚再跟下；③下一组换另一只脚先上
            时间：每1–2分钟一段；休息1分钟
            要点：使用稳固低台阶；靠近扶手；不要跳跃
            """,
            intensity: """
            合适：呼吸稍快；上下台阶时身体不摇晃
            过强：膝盖疼、脚步变乱或身体明显摇晃
            调整方法：立即停止；膝盖疼时不要继续；其他情况放慢速度
            """
        ),
        "private-open-outdoor-moderate-brisk-walk": ExerciseInstructionCopy(
            howTo: """
            步骤：①先慢走，再逐渐加快；②保持自然步幅和稳定节奏
            时间：每5分钟一段；休息1分钟
            要点：选择平坦路线；结束前逐渐放慢
            """,
            intensity: """
            合适：能完整说话；不能轻松唱歌
            过强：说一句话需要多次换气；或步伐不稳
            调整方法：降低速度；必要时停下休息
            """
        ),
        "private-open-outdoor-shallow-squat": ExerciseInstructionCopy(
            howTo: """
            步骤：①双脚与肩差不多宽，脚尖向前；②臀部向后，慢慢浅蹲；③再慢慢站起
            时间：每组8–12次；休息1–2分钟
            要点：靠近稳固支撑；膝盖朝向脚尖；只做浅蹲
            """,
            intensity: """
            合适：能正常呼吸；站起时身体不摇晃
            过强：需要憋气；或膝盖疼、无法站稳
            调整方法：立即站起；下次少蹲一些或减少次数
            """
        ),
        "private-open-outdoor-wall-push-up": ExerciseInstructionCopy(
            howTo: """
            步骤：①面对墙站约一臂远，双手与肩同高撑墙；②弯曲手肘靠近墙面；③慢慢推回
            时间：每组8–12次；休息1–2分钟
            要点：确认墙面稳固；从头到脚保持一条直线
            """,
            intensity: """
            合适：能正常呼吸；推回时身体保持稳定
            过强：需要憋气；或腰背弯曲、肩膀疼
            调整方法：肩膀疼时停止；其他情况站近墙面或减少次数
            """
        ),
        "private-open-outdoor-wall-sit": ExerciseInstructionCopy(
            howTo: """
            步骤：①背部贴墙，双脚向前半步；②慢慢下滑到浅蹲；③短暂保持后站起
            时间：保持5–10秒；休息20–30秒
            要点：只蹲到不疼且能顺利站回的位置；不要憋气
            """,
            intensity: """
            合适：能正常呼吸；双腿没有明显发抖
            过强：憋气、头晕、疼痛或双腿明显发抖
            调整方法：立即站起；下次少蹲一些或缩短时间
            """
        ),
        "private-open-outdoor-supported-back-leg-raise": ExerciseInstructionCopy(
            howTo: """
            步骤：①一手扶墙，身体站直；②一条腿小幅向后抬起；③慢慢放下后换腿
            时间：每侧8–12次；休息1–2分钟
            要点：上身不要前倾；腰部不要向后仰
            """,
            intensity: """
            合适：能正常呼吸；抬腿时身体不摇晃
            过强：需要摆动身体；或腰部、大腿根部疼
            调整方法：立即停止；下次少抬一些或减少次数
            """
        ),
        "private-open-outdoor-low-step-up": ExerciseInstructionCopy(
            howTo: """
            步骤：①一只脚踏上台阶，另一只脚跟上；②第一只脚先踏下，另一只脚再跟下；③下一组换另一只脚先上
            时间：每1–2分钟一段；休息1分钟
            要点：使用稳固低台阶；靠近扶手；不要跳跃
            """,
            intensity: """
            合适：呼吸稍快；上下台阶时身体不摇晃
            过强：膝盖疼、脚步变乱或身体明显摇晃
            调整方法：立即停止；膝盖疼时不要继续；其他情况放慢速度
            """
        )
    ]

    static func localizedCopy(for exerciseID: String) -> ExerciseInstructionCopy? {
        if L10n.language == .english {
            return englishByExerciseID[exerciseID] ?? byExerciseID[exerciseID]
        }
        return byExerciseID[exerciseID]
    }

    private static let englishByExerciseID: [String: ExerciseInstructionCopy] = [
        "private-indoor-march-in-place": .init(
            howTo: """
            Steps: 1. Stand upright and lift each foot in turn. 2. Let your arms swing naturally.
            Timing: Work for 5 minutes, then rest for 1 minute.
            Key points: Keep your steps light and steady. Do not jump or lift your knees too high.
            """,
            intensity: """
            Suitable: You can speak in full sentences but cannot sing easily.
            Too hard: You can say only a few words, or your steps become unsteady.
            Adjust: Slow down. If you still cannot speak in full sentences, continue resting.
            """
        ),
        "private-indoor-sit-to-stand": .init(
            howTo: """
            Steps: 1. Sit midway on a stable chair with both feet flat. 2. Lean slightly forward and stand slowly. 3. Sit down slowly.
            Timing: Do 8–12 repetitions, then rest for 1–2 minutes.
            Key points: Do not use a chair with wheels. Hold the armrests if needed.
            """,
            intensity: """
            Suitable: You can breathe normally and remain steady while standing and sitting.
            Too hard: You need to hold your breath, have knee pain, or cannot lower yourself slowly.
            Adjust: Stop if your knees hurt. Otherwise, do fewer repetitions or use the armrests.
            """
        ),
        "private-indoor-wall-push-up": .init(
            howTo: """
            Steps: 1. Face a wall about one arm's length away, with hands at shoulder height. 2. Bend your elbows toward the wall. 3. Push back slowly.
            Timing: Do 8–12 repetitions, then rest for 1–2 minutes.
            Key points: Keep a straight line from head to heels and keep your heels down.
            """,
            intensity: """
            Suitable: You can breathe normally and keep your body steady while pushing back.
            Too hard: You need to hold your breath, your back bends, or your shoulders hurt.
            Adjust: Stop if your shoulders hurt. Otherwise, stand closer to the wall or do fewer repetitions.
            """
        ),
        "private-indoor-wall-sit": .init(
            howTo: """
            Steps: 1. Rest your back against a wall and place your feet half a step forward. 2. Slide down into a shallow squat. 3. Hold briefly, then stand.
            Timing: Hold for 5–10 seconds, then rest for 20–30 seconds.
            Key points: Squat only as far as is comfortable and easy to stand from. Do not hold your breath.
            """,
            intensity: """
            Suitable: You can breathe normally and your legs are not visibly shaking.
            Too hard: You hold your breath, feel dizzy or pain, or your legs shake noticeably.
            Adjust: Stand up immediately. Next time, squat less deeply or hold for less time.
            """
        ),
        "private-indoor-seated-alternating-knee-lift": .init(
            howTo: """
            Steps: 1. Sit securely with both feet on the floor. 2. Lift each knee in turn. 3. Lower it slowly.
            Timing: Work for 5 minutes, then rest for 1 minute.
            Key points: Keep your upper body upright and lift only to a comfortable height.
            """,
            intensity: """
            Suitable: You can speak in full sentences without leaning back noticeably.
            Too hard: You can say only a few words, or your lower back feels uncomfortable.
            Adjust: Slow down and lift your knees less high.
            """
        ),
        "private-indoor-seated-knee-extension": .init(
            howTo: """
            Steps: 1. Sit securely with both feet on the floor. 2. Slowly straighten one leg forward. 3. Lower it slowly, then switch legs.
            Timing: Do 8–12 repetitions per side, then rest for 1–2 minutes.
            Key points: Do not lean back. Stop immediately if your knee hurts.
            """,
            intensity: """
            Suitable: You can breathe normally and raise and lower your lower leg slowly.
            Too hard: You need to lean back for momentum, or your knee hurts.
            Adjust: Stop immediately. Next time, straighten less or do fewer repetitions.
            """
        ),
        "public-indoor-slow-walk": .init(
            howTo: """
            Steps: 1. Choose a level walkway and begin slowly. 2. Walk naturally with relaxed arm swings.
            Timing: Walk for 5 minutes, then rest for 1 minute.
            Key points: Look ahead and avoid slippery surfaces and obstacles.
            """,
            intensity: """
            Suitable: Your breathing is slightly faster, but you can still speak in full sentences.
            Too hard: You cannot finish a sentence, or your steps become unsteady.
            Adjust: Slow down and stop to rest if needed.
            """
        ),
        "public-indoor-march-in-place": .init(
            howTo: """
            Steps: 1. Stand upright and lift each foot in turn. 2. Let your arms swing naturally.
            Timing: Work for 5 minutes, then rest for 1 minute.
            Key points: Choose a place where you will not block anyone. Keep steps light and steady; do not jump.
            """,
            intensity: """
            Suitable: You can speak in full sentences but cannot sing easily.
            Too hard: You can say only a few words, or your steps become unsteady.
            Adjust: Slow down and stop to rest if needed.
            """
        ),
        "public-indoor-side-step": .init(
            howTo: """
            Steps: 1. Step left with your left foot and bring your right foot in. 2. Repeat to the right.
            Timing: Work for 2–3 minutes, then rest for 1 minute.
            Key points: Check that both sides are clear. Do not cross your feet or jump.
            """,
            intensity: """
            Suitable: Your breathing is natural and your body stays steady from side to side.
            Too hard: Your steps become confused, or your body sways noticeably.
            Adjust: Take smaller steps, slow down, or hold a stable support.
            """
        ),
        "public-indoor-calf-raise": .init(
            howTo: """
            Steps: 1. Hold a stable support and stand firmly. 2. Slowly raise your heels. 3. Slowly lower them.
            Timing: Do 8–12 repetitions, then rest for 1–2 minutes.
            Key points: Keep your body upright and do not bounce quickly.
            """,
            intensity: """
            Suitable: You can breathe normally and stay steady while rising and lowering.
            Too hard: You need to hold your breath, your calves hurt, or your body sways.
            Adjust: Lower your heels immediately. Rest longer or do fewer repetitions.
            """
        ),
        "public-indoor-forward-back-tap": .init(
            howTo: """
            Steps: 1. Tap your right foot forward and return. 2. Tap it backward and return. 3. Switch to the left foot.
            Timing: Work for 2–3 minutes, then rest for 1 minute.
            Key points: Tap lightly, keep your body upright, and do not jump.
            """,
            intensity: """
            Suitable: Your breathing is natural and your body stays steady while tapping.
            Too hard: Your steps become confused, or your body sways noticeably.
            Adjust: Shorten the tapping distance, slow down, or hold a stable support.
            """
        ),
        "public-indoor-supported-side-leg-raise": .init(
            howTo: """
            Steps: 1. Hold a wall with one hand and stand upright. 2. Lift one leg slightly to the side. 3. Lower it slowly, then switch legs.
            Timing: Do 8–12 repetitions per side, then rest for 1–2 minutes.
            Key points: Keep your toes forward and do not lean your upper body sideways.
            """,
            intensity: """
            Suitable: You can breathe normally and stay steady while lifting your leg.
            Too hard: You need to lean for momentum, or you feel pain at the top of your thigh.
            Adjust: Stop immediately. Next time, lift less or do fewer repetitions.
            """
        ),
        "public-outdoor-slow-walk": .init(
            howTo: """
            Steps: 1. Choose a level route and begin slowly. 2. Walk naturally with relaxed arm swings.
            Timing: Walk for 5 minutes, then rest for 1 minute.
            Key points: Look ahead and avoid slippery surfaces and obstacles.
            """,
            intensity: """
            Suitable: Your breathing is slightly faster, but you can still speak in full sentences.
            Too hard: You cannot finish a sentence, or your steps become unsteady.
            Adjust: Slow down immediately and stop to rest if needed.
            """
        ),
        "public-outdoor-moderate-brisk-walk": .init(
            howTo: """
            Steps: 1. Start slowly, then gradually speed up. 2. Keep a natural stride and steady rhythm.
            Timing: Walk for 5 minutes, then rest for 1 minute.
            Key points: Do not race. Slow down gradually before finishing.
            """,
            intensity: """
            Suitable: You can speak in full sentences but cannot sing easily.
            Too hard: You need several breaths to finish a sentence, or your steps become unsteady.
            Adjust: Reduce your speed and stop to rest if needed.
            """
        ),
        "public-outdoor-side-step": .init(
            howTo: """
            Steps: 1. Step left with your left foot and bring your right foot in. 2. Repeat to the right.
            Timing: Work for 2–3 minutes, then rest for 1 minute.
            Key points: Choose a level, clear area. Do not cross your feet or jump.
            """,
            intensity: """
            Suitable: Your breathing is natural and your body stays steady from side to side.
            Too hard: Your steps become confused, or your body sways noticeably.
            Adjust: Take smaller steps, slow down, or hold a stable support.
            """
        ),
        "public-outdoor-step-jack": .init(
            howTo: """
            Steps: 1. Step one foot out to the side. 2. Bring it back and switch feet. 3. Raise your arms naturally if comfortable.
            Timing: Work for 2–3 minutes, then rest for 1 minute.
            Key points: Step only; do not jump. Make sure the area is clear.
            """,
            intensity: """
            Suitable: You can speak in full sentences and remain steady.
            Too hard: You can say only a few words, or your steps become unsteady.
            Adjust: Slow down, stop raising your arms, or pause to rest.
            """
        ),
        "public-outdoor-forward-back-tap": .init(
            howTo: """
            Steps: 1. Tap your right foot forward and return. 2. Tap it backward and return. 3. Switch to the left foot.
            Timing: Work for 2–3 minutes, then rest for 1 minute.
            Key points: Choose a level area, tap lightly, and do not jump.
            """,
            intensity: """
            Suitable: Your breathing is natural and your body stays steady while tapping.
            Too hard: Your steps become confused, or your body sways noticeably.
            Adjust: Shorten the tapping distance, slow down, or hold a stable support.
            """
        ),
        "public-outdoor-low-step-up": .init(
            howTo: """
            Steps: 1. Step onto a low step with one foot, then bring up the other. 2. Step down with the first foot, then the other. 3. Lead with the other foot next time.
            Timing: Work for 1–2 minutes, then rest for 1 minute.
            Key points: Use a stable low step, stay near a handrail, and do not jump.
            """,
            intensity: """
            Suitable: Your breathing is slightly faster and your body stays steady on the step.
            Too hard: Your knees hurt, your steps become confused, or your body sways noticeably.
            Adjust: Stop immediately. Do not continue with knee pain; otherwise slow down.
            """
        ),
        "private-open-outdoor-moderate-brisk-walk": .init(
            howTo: """
            Steps: 1. Start slowly, then gradually speed up. 2. Keep a natural stride and steady rhythm.
            Timing: Walk for 5 minutes, then rest for 1 minute.
            Key points: Choose a level route and slow down gradually before finishing.
            """,
            intensity: """
            Suitable: You can speak in full sentences but cannot sing easily.
            Too hard: You need several breaths to finish a sentence, or your steps become unsteady.
            Adjust: Reduce your speed and stop to rest if needed.
            """
        ),
        "private-open-outdoor-shallow-squat": .init(
            howTo: """
            Steps: 1. Stand with feet about shoulder-width apart and toes forward. 2. Move your hips back into a shallow squat. 3. Stand slowly.
            Timing: Do 8–12 repetitions, then rest for 1–2 minutes.
            Key points: Stay near a stable support, keep knees aligned with toes, and squat only slightly.
            """,
            intensity: """
            Suitable: You can breathe normally and stay steady while standing.
            Too hard: You need to hold your breath, your knees hurt, or you cannot stand steadily.
            Adjust: Stand up immediately. Next time, squat less deeply or do fewer repetitions.
            """
        ),
        "private-open-outdoor-wall-push-up": .init(
            howTo: """
            Steps: 1. Face a wall about one arm's length away, with hands at shoulder height. 2. Bend your elbows toward the wall. 3. Push back slowly.
            Timing: Do 8–12 repetitions, then rest for 1–2 minutes.
            Key points: Make sure the wall is stable and keep a straight line from head to heels.
            """,
            intensity: """
            Suitable: You can breathe normally and keep your body steady while pushing back.
            Too hard: You need to hold your breath, your back bends, or your shoulders hurt.
            Adjust: Stop if your shoulders hurt. Otherwise, stand closer to the wall or do fewer repetitions.
            """
        ),
        "private-open-outdoor-wall-sit": .init(
            howTo: """
            Steps: 1. Rest your back against a wall and place your feet half a step forward. 2. Slide down into a shallow squat. 3. Hold briefly, then stand.
            Timing: Hold for 5–10 seconds, then rest for 20–30 seconds.
            Key points: Squat only as far as is comfortable and easy to stand from. Do not hold your breath.
            """,
            intensity: """
            Suitable: You can breathe normally and your legs are not visibly shaking.
            Too hard: You hold your breath, feel dizzy or pain, or your legs shake noticeably.
            Adjust: Stand up immediately. Next time, squat less deeply or hold for less time.
            """
        ),
        "private-open-outdoor-supported-back-leg-raise": .init(
            howTo: """
            Steps: 1. Hold a wall with one hand and stand upright. 2. Lift one leg slightly backward. 3. Lower it slowly, then switch legs.
            Timing: Do 8–12 repetitions per side, then rest for 1–2 minutes.
            Key points: Do not lean forward or arch your lower back.
            """,
            intensity: """
            Suitable: You can breathe normally and stay steady while lifting your leg.
            Too hard: You need to swing your body, or your lower back or upper thigh hurts.
            Adjust: Stop immediately. Next time, lift less or do fewer repetitions.
            """
        ),
        "private-open-outdoor-low-step-up": .init(
            howTo: """
            Steps: 1. Step onto a low step with one foot, then bring up the other. 2. Step down with the first foot, then the other. 3. Lead with the other foot next time.
            Timing: Work for 1–2 minutes, then rest for 1 minute.
            Key points: Use a stable low step, stay near a handrail, and do not jump.
            """,
            intensity: """
            Suitable: Your breathing is slightly faster and your body stays steady on the step.
            Too hard: Your knees hurt, your steps become confused, or your body sways noticeably.
            Adjust: Stop immediately. Do not continue with knee pain; otherwise slow down.
            """
        )
    ]
}
