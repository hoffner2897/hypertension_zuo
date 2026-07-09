export type BPInterpretationCategory = "normal" | "borderline" | "high_home" | "low" | "urgent" | "insufficient_data";
export type BPInterpretationSeverity = "reassuring" | "watch" | "repeat" | "follow_up" | "urgent";

export interface BPInterpretationReadingInput {
  systolicBp: number;
  diastolicBp: number;
  bpMonitorPulse?: number | null;
  measurementTime: string;
}

export interface BPRecentReadingInput {
  systolicBp: number;
  diastolicBp: number;
  measurementTime?: string | null;
}

export interface BPMedicalContextInput {
  knownHypertension?: boolean;
  diabetes?: boolean;
  kidneyDisease?: boolean;
  pregnancy?: boolean;
  cardiovascularDisease?: boolean;
  currentBpMedication?: boolean;
}

export interface BPMeasurementContextInput {
  rested5Min?: boolean;
  caffeineExerciseSmokingAlcoholRecently?: boolean;
  correctCuff?: boolean;
  seated?: boolean;
  armAtHeartLevel?: boolean;
}

export interface BPInterpretationInput extends BPInterpretationReadingInput {
  age?: number | null;
  sex?: string | null;
  heightCm?: number | null;
  weightKg?: number | null;
  todaySteps?: number | null;
  yesterdayExerciseMinutes?: number | null;
  restingHeartRate?: number | null;
  averageSleepHoursLast7Days?: number | null;
  recentBpReadings?: BPRecentReadingInput[];
  symptoms?: string[];
  medicalContext?: BPMedicalContextInput;
  measurementContext?: BPMeasurementContextInput;
}

export interface BPHistorySummary {
  averageSystolic: number | null;
  averageDiastolic: number | null;
  readingCount: number;
  daysCovered: number | null;
  averageHomeHigh: boolean;
  pattern: "none" | "single" | "one_off" | "consistent_high" | "variable" | "improving" | "worsening" | "mostly_normal";
  elevationDriver: "systolic" | "diastolic" | "both" | "none";
}

export interface BPInterpretationResult {
  category: BPInterpretationCategory;
  severity: BPInterpretationSeverity;
  title: string;
  summary: string;
  reasons: string[];
  personalContextNotes: string[];
  measurementQualityNotes: string[];
  nextSteps: string[];
  safetyNote: string;
  disclaimer: string;
}

export interface BPBaseInterpretation extends BPInterpretationResult {
  historySummary: BPHistorySummary;
  bmi: number | null;
  safetySymptoms: string[];
}

const urgentSymptoms = new Set([
  "chest_pain",
  "shortness_of_breath",
  "severe_headache",
  "confusion",
  "weakness_numbness",
  "vision_changes",
  "fainting"
]);

export function makeRuleBasedInterpretation(input: BPInterpretationInput): BPBaseInterpretation {
  const systolic = input.systolicBp;
  const diastolic = input.diastolicBp;

  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic) || systolic <= diastolic) {
    return {
      category: "insufficient_data",
      severity: "watch",
      title: "还需要完整读数",
      summary: "请先确认收缩压和舒张压读数，再查看解释。",
      reasons: ["当前读数不完整或格式不符合常见血压读数。"],
      personalContextNotes: [],
      measurementQualityNotes: ["请确认读数来自同一次测量，并检查单位为 mmHg。"],
      nextSteps: ["重新输入或重新识别本次读数。"],
      safetyNote: "如出现胸痛、气短、剧烈头痛、视物异常、肢体无力或意识异常，请立即寻求急诊帮助。",
      disclaimer: disclaimerText,
      historySummary: emptyHistorySummary(),
      bmi: null,
      safetySymptoms: []
    };
  }

  const category = classifyBp(systolic, diastolic);
  const historySummary = summarizeHistory(input.recentBpReadings ?? [], input);
  const bmi = calculateBmi(input.heightCm, input.weightKg);
  const safetySymptoms = (input.symptoms ?? []).filter((symptom) => urgentSymptoms.has(symptom));
  const personalContextNotes = makePersonalContextNotes(input, bmi);
  const measurementQualityNotes = makeMeasurementQualityNotes(category, input.measurementContext);
  const reasons = makeReasons(input, category, historySummary);
  const nextSteps = makeNextSteps(input, category, historySummary, safetySymptoms);
  const severity = makeSeverity(input, category, historySummary, safetySymptoms);

  return {
    category,
    severity,
    title: titleForCategory(category),
    summary: summaryForCategory(category, historySummary),
    reasons,
    personalContextNotes,
    measurementQualityNotes,
    nextSteps,
    safetyNote: safetyNoteFor(category, safetySymptoms),
    disclaimer: disclaimerText,
    historySummary,
    bmi,
    safetySymptoms
  };
}

export function normalizeInterpretationResult(value: unknown, base: BPBaseInterpretation): BPInterpretationResult {
  if (!isRecord(value)) {
    return stripInternalFields(base);
  }

  return {
    category: base.category,
    severity: base.severity,
    title: cleanString(value.title, base.title),
    summary: cleanString(value.summary, base.summary),
    reasons: cleanStringArray(value.reasons, base.reasons),
    personalContextNotes: cleanStringArray(value.personalContextNotes, base.personalContextNotes),
    measurementQualityNotes: cleanStringArray(value.measurementQualityNotes, base.measurementQualityNotes),
    nextSteps: cleanStringArray(value.nextSteps, base.nextSteps),
    safetyNote: cleanString(value.safetyNote, base.safetyNote),
    disclaimer: cleanString(value.disclaimer, base.disclaimer)
  };
}

export function stripInternalFields(base: BPBaseInterpretation): BPInterpretationResult {
  return {
    category: base.category,
    severity: base.severity,
    title: base.title,
    summary: base.summary,
    reasons: base.reasons,
    personalContextNotes: base.personalContextNotes,
    measurementQualityNotes: base.measurementQualityNotes,
    nextSteps: base.nextSteps,
    safetyNote: base.safetyNote,
    disclaimer: base.disclaimer
  };
}

function classifyBp(systolic: number, diastolic: number): BPInterpretationCategory {
  if (systolic >= 180 || diastolic >= 120) {
    return "urgent";
  }

  if (systolic >= 135 || diastolic >= 85) {
    return "high_home";
  }

  if (systolic >= 120 || diastolic >= 80) {
    return "borderline";
  }

  if (systolic < 90 || diastolic < 60) {
    return "low";
  }

  return "normal";
}

function summarizeHistory(readings: BPRecentReadingInput[], current: BPInterpretationReadingInput): BPHistorySummary {
  const usable = [...readings, current]
    .filter((reading) => Number.isFinite(reading.systolicBp) && Number.isFinite(reading.diastolicBp))
    .slice(0, 30);

  if (usable.length === 0) {
    return emptyHistorySummary();
  }

  const averageSystolic = round(usable.reduce((sum, reading) => sum + reading.systolicBp, 0) / usable.length, 0);
  const averageDiastolic = round(usable.reduce((sum, reading) => sum + reading.diastolicBp, 0) / usable.length, 0);
  const averageHomeHigh = averageSystolic >= 135 || averageDiastolic >= 85;
  const elevationDriver = makeElevationDriver(averageSystolic, averageDiastolic);
  const daysCovered = countDaysCovered(usable);
  const pattern = makeHistoryPattern(usable, averageHomeHigh);

  return {
    averageSystolic,
    averageDiastolic,
    readingCount: usable.length,
    daysCovered,
    averageHomeHigh,
    pattern,
    elevationDriver
  };
}

function makeHistoryPattern(readings: BPRecentReadingInput[], averageHomeHigh: boolean): BPHistorySummary["pattern"] {
  if (readings.length <= 1) {
    return "single";
  }

  const highCount = readings.filter((reading) => reading.systolicBp >= 135 || reading.diastolicBp >= 85).length;
  const systolicValues = readings.map((reading) => reading.systolicBp);
  const diastolicValues = readings.map((reading) => reading.diastolicBp);
  const variable = range(systolicValues) >= 25 || range(diastolicValues) >= 15;
  const ordered = readings
    .filter((reading) => reading.measurementTime)
    .sort((left, right) => new Date(left.measurementTime ?? "").getTime() - new Date(right.measurementTime ?? "").getTime());

  if (ordered.length >= 4) {
    const midpoint = Math.floor(ordered.length / 2);
    const early = averagePair(ordered.slice(0, midpoint));
    const late = averagePair(ordered.slice(midpoint));
    if (late.systolic <= early.systolic - 5 && late.diastolic <= early.diastolic - 3) {
      return "improving";
    }
    if (late.systolic >= early.systolic + 5 || late.diastolic >= early.diastolic + 3) {
      return "worsening";
    }
  }

  if (variable) {
    return "variable";
  }

  if (averageHomeHigh && highCount >= Math.ceil(readings.length * 0.6)) {
    return "consistent_high";
  }

  if (highCount === 1) {
    return "one_off";
  }

  return "mostly_normal";
}

function makeSeverity(
  input: BPInterpretationInput,
  category: BPInterpretationCategory,
  history: BPHistorySummary,
  safetySymptoms: string[]
): BPInterpretationSeverity {
  if (category === "urgent" || safetySymptoms.length > 0) {
    return "urgent";
  }

  if (category === "high_home") {
    return hasMedicalFollowUpContext(input) || history.averageHomeHigh ? "follow_up" : "repeat";
  }

  if (category === "borderline" || category === "low") {
    return hasMedicalFollowUpContext(input) ? "follow_up" : "watch";
  }

  return "reassuring";
}

function makeReasons(input: BPInterpretationInput, category: BPInterpretationCategory, history: BPHistorySummary): string[] {
  const reasons: string[] = [];

  if (category === "urgent") {
    reasons.push("本次读数达到需要高度重视的范围。");
  } else if (category === "high_home") {
    reasons.push("家庭血压场景下，单次读数达到或超过 135/85 mmHg 时需要复测和观察平均值。");
  } else if (category === "borderline") {
    reasons.push("本次读数接近偏高范围，可能受休息、压力、睡眠或测量条件影响。");
  } else if (category === "low") {
    reasons.push("本次读数低于常见参考范围，建议结合自身感受观察。");
  } else {
    reasons.push("本次家庭血压读数在常见正常范围内。");
  }

  if (history.readingCount > 1 && history.averageSystolic !== null && history.averageDiastolic !== null) {
    reasons.push(`近 ${history.readingCount} 次平均约为 ${history.averageSystolic}/${history.averageDiastolic} mmHg。`);
  }

  if (history.pattern === "consistent_high") {
    reasons.push("近期多次读数平均仍偏高，单次读数之外的趋势也值得关注。");
  } else if (history.pattern === "one_off") {
    reasons.push("目前更像单次偏高，需要规范复测后再判断趋势。");
  } else if (history.pattern === "variable") {
    reasons.push("近期读数波动较大，测量条件可能影响结果。");
  } else if (history.pattern === "improving") {
    reasons.push("近期读数有改善迹象，仍建议继续记录。");
  } else if (history.pattern === "worsening") {
    reasons.push("近期读数有上升迹象，建议更密切观察。");
  }

  if (input.bpMonitorPulse && input.bpMonitorPulse >= 100) {
    reasons.push("本次脉搏偏快，可能与活动、紧张、咖啡因、睡眠或身体不适有关。");
  }

  return reasons.slice(0, 5);
}

function makePersonalContextNotes(input: BPInterpretationInput, bmi: number | null): string[] {
  const notes: string[] = [];

  if (input.age !== null && input.age !== undefined && input.age >= 60) {
    notes.push("年龄增加时，更建议关注连续读数和长期趋势。");
  }

  if (bmi !== null && bmi >= 24) {
    notes.push(`按中国成人 BMI 参考，当前 BMI 约 ${bmi.toFixed(1)}，可能与生活方式相关风险有关。`);
  }

  if (input.averageSleepHoursLast7Days !== null && input.averageSleepHoursLast7Days !== undefined && input.averageSleepHoursLast7Days < 6) {
    notes.push("近期睡眠偏少，可能让血压短期更容易偏高。");
  }

  if (input.todaySteps !== null && input.todaySteps !== undefined && input.todaySteps < 4000) {
    notes.push("今日步数偏少，可作为生活方式背景一起观察。");
  }

  if (input.restingHeartRate !== null && input.restingHeartRate !== undefined && input.restingHeartRate >= 90) {
    notes.push("静息心率偏快时，可留意压力、睡眠、近期活动和身体状态。");
  }

  if (hasMedicalFollowUpContext(input)) {
    notes.push("已有相关健康背景或正在用药时，更建议把连续家庭血压记录带给医生参考。");
  }

  return notes.slice(0, 5);
}

function makeMeasurementQualityNotes(category: BPInterpretationCategory, context?: BPMeasurementContextInput): string[] {
  const notes: string[] = [];
  const shouldAlwaysInclude = category === "borderline" || category === "high_home" || category === "urgent";

  if (shouldAlwaysInclude) {
    notes.push("请尽量在安静坐位休息 5 分钟后测量，袖带合适，手臂与心脏同高。");
  }

  if (context?.rested5Min === false) {
    notes.push("本次测量前可能休息不足，建议按规范复测。");
  }
  if (context?.caffeineExerciseSmokingAlcoholRecently === true) {
    notes.push("咖啡因、运动、吸烟或饮酒后短时间内，读数可能暂时偏高。");
  }
  if (context?.correctCuff === false) {
    notes.push("袖带大小或佩戴不合适会影响读数。");
  }
  if (context?.seated === false || context?.armAtHeartLevel === false) {
    notes.push("坐姿和手臂高度不规范时，建议重新测量。");
  }

  if (notes.length === 0) {
    notes.push("建议固定时间、固定姿势记录，方便比较趋势。");
  }

  return notes.slice(0, 4);
}

function makeNextSteps(
  input: BPInterpretationInput,
  category: BPInterpretationCategory,
  history: BPHistorySummary,
  safetySymptoms: string[]
): string[] {
  if (category === "urgent" || safetySymptoms.length > 0) {
    return [
      "如伴有胸痛、气短、剧烈头痛、视物异常、肢体无力或意识异常，请立即寻求急诊帮助。",
      "若没有明显不适，也建议安静休息后尽快复测，并考虑联系医生。"
    ];
  }

  if (category === "high_home") {
    const steps = [
      "安静休息 5 分钟后复测一次，并记录测量条件。",
      "建议连续几天按规范测量，观察家庭平均血压是否仍超过 135/85 mmHg。"
    ];
    if (history.averageHomeHigh || hasMedicalFollowUpContext(input)) {
      steps.push("如果连续平均值仍偏高，建议带记录咨询医生。");
    }
    return steps;
  }

  if (category === "borderline") {
    return [
      "休息后可复测，并观察接下来几天的平均值。",
      "继续记录睡眠、活动和测量时间，帮助理解波动。"
    ];
  }

  if (category === "low") {
    return [
      "如有头晕、乏力、胸闷、晕厥等不适，请及时寻求医疗帮助。",
      "如果没有不适，可在相同条件下复测并继续记录。"
    ];
  }

  return ["继续保持规律记录即可。", "可固定在早晚相近时间测量，方便观察趋势。"];
}

function titleForCategory(category: BPInterpretationCategory): string {
  switch (category) {
    case "urgent":
      return "这次读数需要高度重视";
    case "high_home":
      return "这次家庭血压读数偏高";
    case "borderline":
      return "这次读数接近偏高范围";
    case "low":
      return "这次读数偏低";
    case "normal":
      return "这次读数在常见正常范围内";
    case "insufficient_data":
      return "还需要完整读数";
  }
}

function summaryForCategory(category: BPInterpretationCategory, history: BPHistorySummary): string {
  switch (category) {
    case "urgent":
      return "如伴有明显不适或危险症状，请立即寻求急诊帮助。";
    case "high_home":
      return history.averageHomeHigh
        ? "近期家庭平均血压也偏高，建议连续记录并咨询医生。"
        : "单次读数不能诊断高血压，建议规范复测并观察几天平均值。";
    case "borderline":
      return "建议在安静休息后复测，并观察接下来几天的平均值。";
    case "low":
      return "请结合是否有头晕、乏力等不适，并在相同条件下复测。";
    case "normal":
      return "继续保持记录即可。";
    case "insufficient_data":
      return "请先确认本次收缩压和舒张压。";
  }
}

function safetyNoteFor(category: BPInterpretationCategory, safetySymptoms: string[]): string {
  if (category === "urgent" || safetySymptoms.length > 0) {
    return "如伴有胸痛、气短、剧烈头痛、视物异常、肢体无力、意识异常或晕厥，请立即寻求急诊帮助。";
  }

  return "如出现胸痛、气短、剧烈头痛、视物异常、肢体无力、意识异常或晕厥等症状，请及时寻求医疗帮助。";
}

function hasMedicalFollowUpContext(input: BPInterpretationInput): boolean {
  const context = input.medicalContext;
  return Boolean(
    context?.knownHypertension ||
      context?.diabetes ||
      context?.kidneyDisease ||
      context?.pregnancy ||
      context?.cardiovascularDisease ||
      context?.currentBpMedication
  );
}

function calculateBmi(heightCm?: number | null, weightKg?: number | null): number | null {
  if (!heightCm || !weightKg || heightCm <= 0 || weightKg <= 0) {
    return null;
  }

  return weightKg / (heightCm / 100) ** 2;
}

function makeElevationDriver(systolic: number, diastolic: number): BPHistorySummary["elevationDriver"] {
  const systolicHigh = systolic >= 135;
  const diastolicHigh = diastolic >= 85;

  if (systolicHigh && diastolicHigh) {
    return "both";
  }
  if (systolicHigh) {
    return "systolic";
  }
  if (diastolicHigh) {
    return "diastolic";
  }
  return "none";
}

function countDaysCovered(readings: BPRecentReadingInput[]): number | null {
  const days = new Set<string>();
  for (const reading of readings) {
    if (!reading.measurementTime) {
      continue;
    }
    const date = new Date(reading.measurementTime);
    if (!Number.isNaN(date.getTime())) {
      days.add(date.toISOString().slice(0, 10));
    }
  }

  return days.size > 0 ? days.size : null;
}

function averagePair(readings: BPRecentReadingInput[]) {
  return {
    systolic: readings.reduce((sum, reading) => sum + reading.systolicBp, 0) / readings.length,
    diastolic: readings.reduce((sum, reading) => sum + reading.diastolicBp, 0) / readings.length
  };
}

function range(values: number[]): number {
  return Math.max(...values) - Math.min(...values);
}

function round(value: number, digits: number): number {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function emptyHistorySummary(): BPHistorySummary {
  return {
    averageSystolic: null,
    averageDiastolic: null,
    readingCount: 0,
    daysCovered: null,
    averageHomeHigh: false,
    pattern: "none",
    elevationDriver: "none"
  };
}

function cleanString(value: unknown, fallback: string): string {
  if (typeof value !== "string") {
    return fallback;
  }

  const trimmed = value.trim();
  return trimmed ? trimmed : fallback;
}

function cleanStringArray(value: unknown, fallback: string[]): string[] {
  if (!Array.isArray(value)) {
    return fallback;
  }

  const cleaned = value.filter((item): item is string => typeof item === "string").map((item) => item.trim()).filter(Boolean);
  return cleaned.length > 0 ? cleaned.slice(0, 6) : fallback;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

const disclaimerText = "此解释仅用于健康记录和趋势理解，不构成诊断，也不能替代医生建议或用药调整。";
