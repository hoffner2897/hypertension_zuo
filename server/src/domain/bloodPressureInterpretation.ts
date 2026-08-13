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

export interface BPLifestyleContextInput {
  recentMeals?: Array<{
    mealDate: string;
    mealType: string;
    recognition?: string | null;
    dietaryStructure?: string | null;
    cookingMethod?: string | null;
  }>;
  recentExercises?: Array<{
    localDay: string;
    title: string;
    status: string;
    durationMinutes: number;
    actualDurationMinutes?: number | null;
  }>;
  healthDataSyncedAt?: string | null;
}

export interface BPInterpretationInput extends BPInterpretationReadingInput {
  timeZone?: string;
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
  lifestyleContext?: BPLifestyleContextInput;
}

export interface BPPeriodComparison {
  days: 3 | 7;
  currentAverage: { systolic: number; diastolic: number } | null;
  previousAverage: { systolic: number; diastolic: number } | null;
  currentObservedDays: number;
  previousObservedDays: number;
}

export interface BPInterpretationResult {
  category: BPInterpretationCategory;
  severity: BPInterpretationSeverity;
  bloodPressureSituation: string[];
  reasons: string[];
  nextSteps: string[];
  safetyNote: string;
  disclaimer: string;
}

export interface BPBaseInterpretation extends BPInterpretationResult {
  trendComparisons: BPPeriodComparison[];
  officeClassification: string;
  safetySymptoms: string[];
}

const urgentSymptoms = new Set([
  "chest_pain", "shortness_of_breath", "severe_headache", "confusion",
  "weakness_numbness", "vision_changes", "fainting"
]);

export const bpInterpretationDisclaimer = "血压解读用于记录和观察趋势，不构成诊断，也不能替代医生建议或用药调整。";

export function makeRuleBasedInterpretation(input: BPInterpretationInput): BPBaseInterpretation {
  if (!isValidReading(input)) {
    return {
      category: "insufficient_data",
      severity: "watch",
      bloodPressureSituation: ["本次读数不完整，请确认收缩压、舒张压和单位。"],
      reasons: ["原因：当前数值无法形成有效的血压解读。"],
      nextSteps: ["现在：请重新输入或重新识别同一次测量的完整读数。"],
      safetyNote: defaultSafetyNote,
      disclaimer: bpInterpretationDisclaimer,
      trendComparisons: [],
      officeClassification: "无法分级",
      safetySymptoms: []
    };
  }

  const category = classifyBp(input.systolicBp, input.diastolicBp);
  const safetySymptoms = (input.symptoms ?? []).filter((value) => urgentSymptoms.has(value));
  const trendComparisons = makeTrendComparisons(input);
  const officeClassification = classifyOffice(input.systolicBp, input.diastolicBp);
  const situation = [makeCurrentSituationLine(input, category, officeClassification)];

  for (const comparison of trendComparisons) {
    const line = comparisonLine(comparison);
    if (line) situation.push(line);
  }

  const reasons = makeReasons(input).slice(0, 3);
  const nextSteps = makeNextSteps(input, category, trendComparisons, safetySymptoms).slice(0, 3);
  const severity = makeSeverity(category, trendComparisons, safetySymptoms, input);

  return {
    category,
    severity,
    bloodPressureSituation: situation.slice(0, 3),
    reasons,
    nextSteps,
    safetyNote: category === "urgent" || safetySymptoms.length > 0 ? urgentSafetyNote : defaultSafetyNote,
    disclaimer: bpInterpretationDisclaimer,
    trendComparisons,
    officeClassification,
    safetySymptoms
  };
}

export function normalizeInterpretationResult(value: unknown, base: BPBaseInterpretation): BPInterpretationResult {
  if (!isRecord(value)) return stripInternalFields(base);
  return {
    category: base.category,
    severity: base.severity,
    bloodPressureSituation: cleanLines(value.bloodPressureSituation, base.bloodPressureSituation),
    reasons: cleanLines(value.reasons, base.reasons),
    nextSteps: cleanLines(value.nextSteps, base.nextSteps),
    safetyNote: cleanString(value.safetyNote, base.safetyNote),
    disclaimer: cleanString(value.disclaimer, base.disclaimer)
  };
}

export function stripInternalFields(base: BPBaseInterpretation): BPInterpretationResult {
  return {
    category: base.category,
    severity: base.severity,
    bloodPressureSituation: base.bloodPressureSituation,
    reasons: base.reasons,
    nextSteps: base.nextSteps,
    safetyNote: base.safetyNote,
    disclaimer: base.disclaimer
  };
}

function isValidReading(input: BPInterpretationReadingInput): boolean {
  return Number.isFinite(input.systolicBp) && Number.isFinite(input.diastolicBp) &&
    input.systolicBp > input.diastolicBp && input.systolicBp >= 40 && input.diastolicBp >= 30;
}

function classifyBp(systolic: number, diastolic: number): BPInterpretationCategory {
  if (systolic >= 180 || diastolic >= 120) return "urgent";
  if (systolic < 90 || diastolic < 60) return "low";
  if (systolic >= 135 || diastolic >= 85) return "high_home";
  if (systolic >= 120 || diastolic >= 80) return "borderline";
  return "normal";
}

function classifyOffice(systolic: number, diastolic: number): string {
  if (systolic >= 180 || diastolic >= 110) return "三级高血压范围";
  if (systolic >= 160 || diastolic >= 100) return "二级高血压范围";
  if (systolic >= 140 || diastolic >= 90) return "一级高血压范围";
  if (systolic >= 120 || diastolic >= 80) return "正常高值范围";
  return "正常范围";
}

function makeCurrentSituationLine(input: BPInterpretationInput, category: BPInterpretationCategory, office: string): string {
  const value = `${input.systolicBp}/${input.diastolicBp} mmHg`;
  if (category === "low") return `本次：${value}，低于常见参考范围；如果同样数值在诊室测量，对照为${office}。`;
  if (category === "urgent") return `本次：${value}，达到家庭高血压参考线；如果同样数值在诊室测量，对照为${office}。`;
  if (category === "high_home") return `本次：${value}，达到家庭高血压参考线；如果同样数值在诊室测量，对照为${office}。`;
  return `本次：${value}，未达到家庭高血压参考线；如果同样数值在诊室测量，对照为${office}。`;
}

function makeTrendComparisons(input: BPInterpretationInput): BPPeriodComparison[] {
  const readings = deduplicateReadings([...(input.recentBpReadings ?? []), input]);
  const timeZone = validTimeZone(input.timeZone) ? input.timeZone! : "UTC";
  const anchorDay = localDay(input.measurementTime, timeZone);
  const daily = new Map<string, Array<{ systolic: number; diastolic: number }>>();
  for (const reading of readings) {
    if (!reading.measurementTime || !Number.isFinite(reading.systolicBp) || !Number.isFinite(reading.diastolicBp)) continue;
    const day = localDay(reading.measurementTime, timeZone);
    const bucket = daily.get(day) ?? [];
    bucket.push({ systolic: reading.systolicBp, diastolic: reading.diastolicBp });
    daily.set(day, bucket);
  }
  const dailyAverages = new Map([...daily].map(([day, values]) => [day, average(values)]));
  return ([3, 7] as const).map((days) => {
    const current = rangeAverages(dailyAverages, anchorDay, 0, days - 1);
    const previous = rangeAverages(dailyAverages, anchorDay, days, days * 2 - 1);
    return { days, currentAverage: current.average, previousAverage: previous.average,
      currentObservedDays: current.count, previousObservedDays: previous.count };
  });
}

function comparisonLine(comparison: BPPeriodComparison): string | null {
  const current = comparison.currentAverage;
  if (!current) return null;
  const prefix = `${comparison.days}日：近${comparison.days}日每日均值 ${current.systolic}/${current.diastolic} mmHg`;
  const previous = comparison.previousAverage;
  if (!previous) return `${prefix}，继续记录以观察变化。`;
  const sys = current.systolic - previous.systolic;
  const dia = current.diastolic - previous.diastolic;
  return `${prefix}，比前${comparison.days}日${describePressureDelta("收缩压", sys)}，${describePressureDelta("舒张压", dia)}。`;
}

function describePressureDelta(label: string, delta: number): string {
  if (delta === 0) return `${label}持平`;
  return `${label}${delta > 0 ? "高" : "低"}${Math.abs(delta)} mmHg`;
}

function makeReasons(input: BPInterpretationInput): string[] {
  const lines: string[] = [];
  const meal = input.lifestyleContext?.recentMeals?.find((item) => item.dietaryStructure || item.cookingMethod);
  if (meal) lines.push(`饮食：${shortText(meal.dietaryStructure ?? meal.cookingMethod ?? "近期已有餐食记录。")}`);
  const exercises = input.lifestyleContext?.recentExercises ?? [];
  if (exercises.length > 0) {
    const completed = exercises.filter((item) => item.status === "completed").length;
    lines.push(`运动：近7日记录 ${exercises.length} 次，完成 ${completed} 次，可结合读数继续观察。`);
  }
  if (input.averageSleepHoursLast7Days != null) lines.push(`睡眠：最近同步值约 ${round(input.averageSleepHoursLast7Days, 1)} 小时，可作为读数背景。`);
  else if (input.todaySteps != null) lines.push(`活动：最近同步步数为 ${input.todaySteps} 步，可作为读数背景。`);
  else if (input.bpMonitorPulse != null && input.bpMonitorPulse >= 100) lines.push("背景：本次脉搏较快，活动、紧张或测量条件可能影响读数。");
  if (lines.length === 0) lines.push("原因：本次变化可能与休息、情绪或测量条件有关，需结合后续读数观察。");
  return lines;
}

function makeNextSteps(input: BPInterpretationInput, category: BPInterpretationCategory, trends: BPPeriodComparison[], symptoms: string[]): string[] {
  if (category === "urgent" || symptoms.length > 0) return [
    "现在：停止活动并安静休息，按规范立即复测。",
    "观察：如读数仍处于很高范围，尽快联系医疗服务。",
    "就医：如伴胸痛、气短、严重头痛、视物或意识异常，请立即寻求急诊帮助。"
  ];
  if (category === "low") return [
    "现在：先坐下休息、避免突然起身，并按相同条件复测。",
    "观察：留意头晕、乏力或晕厥，并继续记录。",
    "就医：如不适持续、加重或发生晕厥，请及时联系医生。"
  ];
  const sevenDayHigh = trends.find((item) => item.days === 7)?.currentAverage;
  const threeDayHigh = trends.find((item) => item.days === 3)?.currentAverage;
  const currentHigh = category === "high_home";
  const lines = [currentHigh ? "现在：安静休息 5 分钟后规范复测一次。" : "现在：继续按固定时间和姿势记录血压。"];
  lines.push(threeDayHigh && isHomeHigh(threeDayHigh) ? "观察：近3日均值偏高，继续记录并观察7日均值。" : "观察：结合接下来几天的每日均值判断变化。");
  if (sevenDayHigh && isHomeHigh(sevenDayHigh)) lines.push("就医：近7日均值偏高，可带完整记录联系医生讨论。");
  return lines;
}

function makeSeverity(category: BPInterpretationCategory, trends: BPPeriodComparison[], symptoms: string[], input: BPInterpretationInput): BPInterpretationSeverity {
  if (category === "urgent" || symptoms.length > 0) return "urgent";
  const seven = trends.find((item) => item.days === 7)?.currentAverage;
  if ((seven && isHomeHigh(seven)) || hasMedicalContext(input)) return "follow_up";
  if (category === "high_home") return "repeat";
  if (category === "borderline" || category === "low") return "watch";
  return "reassuring";
}

function hasMedicalContext(input: BPInterpretationInput): boolean {
  return Boolean(input.medicalContext && Object.values(input.medicalContext).some(Boolean));
}

function isHomeHigh(value: { systolic: number; diastolic: number }): boolean { return value.systolic >= 135 || value.diastolic >= 85; }

function rangeAverages(values: Map<string, { systolic: number; diastolic: number }>, anchor: string, from: number, to: number) {
  const selected: Array<{ systolic: number; diastolic: number }> = [];
  for (let offset = from; offset <= to; offset += 1) {
    const value = values.get(shiftDay(anchor, -offset));
    if (value) selected.push(value);
  }
  return { average: selected.length > 0 ? average(selected) : null, count: selected.length };
}

function average(values: Array<{ systolic: number; diastolic: number }>) {
  return { systolic: round(values.reduce((sum, item) => sum + item.systolic, 0) / values.length, 0),
    diastolic: round(values.reduce((sum, item) => sum + item.diastolic, 0) / values.length, 0) };
}

function deduplicateReadings(readings: BPRecentReadingInput[]): BPRecentReadingInput[] {
  const map = new Map<string, BPRecentReadingInput>();
  for (const item of readings) map.set(`${item.measurementTime ?? ""}:${item.systolicBp}:${item.diastolicBp}`, item);
  return [...map.values()];
}

function localDay(value: string, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date(value));
  const part = (type: string) => parts.find((item) => item.type === type)?.value ?? "00";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

function shiftDay(day: string, offset: number): string {
  const date = new Date(`${day}T00:00:00Z`); date.setUTCDate(date.getUTCDate() + offset); return date.toISOString().slice(0, 10);
}

function validTimeZone(value?: string): boolean {
  if (!value) return false;
  try { new Intl.DateTimeFormat("en-US", { timeZone: value }).format(); return true; } catch { return false; }
}

function cleanLines(value: unknown, fallback: string[]): string[] {
  if (!Array.isArray(value)) return fallback;
  const lines = value.filter((item): item is string => typeof item === "string").map((item) => item.replace(/\s+/g, " ").trim()).filter(Boolean).slice(0, 3);
  return lines.length > 0 ? lines : fallback;
}
function cleanString(value: unknown, fallback: string): string { return typeof value === "string" && value.trim() ? value.trim() : fallback; }
function shortText(value: string): string { const text = value.replace(/\s+/g, " ").trim(); return text.length <= 52 ? text : `${text.slice(0, 51)}…`; }
function round(value: number, digits: number): number { const factor = 10 ** digits; return Math.round(value * factor) / factor; }
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null; }

const urgentSafetyNote = "如伴胸痛、气短、严重头痛、视物异常、肢体无力、意识异常或晕厥，请立即寻求急诊帮助。";
const defaultSafetyNote = "如出现胸痛、气短、严重头痛、视物异常、肢体无力、意识异常或晕厥，请及时寻求医疗帮助。";
