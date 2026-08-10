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
            （注：首次练习建议查看动作视频）
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
            （注：首次练习建议查看动作视频）
            """,
            intensity: """
            合适：呼吸稍快；上下台阶时身体不摇晃
            过强：膝盖疼、脚步变乱或身体明显摇晃
            调整方法：立即停止；膝盖疼时不要继续；其他情况放慢速度
            """
        )
    ]
}
