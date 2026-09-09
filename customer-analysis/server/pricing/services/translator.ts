/**
 * מתרגם מונחים אנגליים נפוצים בעולם הכיול לעברית, כדי לאפשר התאמה למחירון שכתוב ברובו בעברית.
 * הלוגיקה: עבור שאילתה שמכילה מילים אנגליות, מוסיפים את התרגום העברי שלהן כטוקנים נוספים,
 * כך ש-"Transonic Flowprobe" יחפש גם "מד זרימה", ו-"Caliper Mitutoyo" יחפש גם "קליבר".
 *
 * המילון בנוי משני שלבים:
 *   1. ביטויים מרובי-מילים (תרמוקאפל, מנקה אולטרסוני וכד') - נבדקים קודם, כי "tensile machine"
 *      צריך להתורגם ל"מכונת מתיחה" ולא נפרד ל"מתיחה" + "מכונה".
 *   2. מילים בודדות - לאחר זיהוי הביטויים, סורקים את כל הטקסט למילים שמופיעות במילון.
 */

// ביטויים מרובי-מילים - תורגמו לפני המילים הבודדות. סדר אינו חשוב; הקוד ממיין לפי אורך.
const EN_PHRASES_TO_HE: Record<string, string[]> = {
  // מכונות בדיקה
  'tensile machine': ['מכונת מתיחה', 'מתיחה'],
  'tensile tester': ['בודק מתיחה', 'מתיחה'],
  'tensile testing': ['בדיקת מתיחה', 'מתיחה'],
  'compression machine': ['מכונת לחיצה', 'לחיצה'],
  'compression tester': ['בודק לחיצה'],
  'impact tester': ['בודק עמידות זעזועים', 'עוצמה'],
  'impact test': ['בדיקת עוצמה'],
  'hardness tester': ['בודק קושי', 'קושי'],
  'leak tester': ['בודק דליפות', 'דליפות'],
  'leakage tester': ['בודק דליפות', 'דליפות'],
  'leak detector': ['גלאי דליפות', 'דליפות'],
  'pressure tester': ['בודק לחץ', 'לחץ'],
  'safety tester': ['בודק בטיחות', 'בטיחות'],
  'insulation tester': ['בודק בידוד', 'בידוד'],
  'earth tester': ['בודק הארקה', 'הארקה'],
  'ground tester': ['בודק הארקה', 'הארקה'],
  'battery tester': ['בודק סוללה', 'סוללה'],

  // ניקוי וטיפול
  'ultrasonic cleaner': ['מנקה אולטרסוני', 'אולטרסוני', 'ניקוי אולטרסוני'],
  'ultrasonic bath': ['אמבט אולטרסוני', 'אולטרסוני'],
  'fume hood': ['מנדף', 'מנדף כימי'],
  'safety cabinet': ['ארון בטיחות'],
  'laminar flow': ['זרימה למינרית'],
  'clean bench': ['שולחן נקי'],

  // מדידה - מ.ב.א. משתמשים ב-"זחון" (לא "קליבר") עבור caliper. חובה לכלול שניהם.
  'digital indicator': ['מחוון דיגיטלי', 'מחוון', 'דיגיטלי'],
  'digital readout': ['קורא דיגיטלי'],
  'digital caliper': ['זחון דיגיטלי', 'זחון', 'קליבר דיגיטלי'],
  'vernier caliper': ['זחון ורנייר', 'זחון', 'קליבר ורנייר'],
  'dial caliper': ['זחון מחוגי', 'זחון', 'קליבר מחוגי'],
  'dial indicator': ['מחוון מחוגי', 'מחוון'],
  'depth gauge': ['מד עומק', 'עומק'],
  'depth gage': ['מד עומק', 'עומק'],
  'height gauge': ['מד גובה', 'גובה'],
  'thickness gauge': ['מד עובי', 'עובי'],
  'feeler gauge': ['מד רווח', 'רווח'],
  'thread gauge': ['מד תבריג', 'תבריג'],
  'pin gauge': ['מד פין', 'פין'],
  'pin gage': ['מד פין', 'פין'],
  'plug gauge': ['מד פין', 'פין'],
  'ring gauge': ['מד טבעת'],
  'gauge block': ['קוביית מד', 'מד'],
  'block gauge': ['קוביית מד'],
  'go no go': ['גו נו גו'],
  'inside micrometer': ['מיקרומטר פנימי'],
  'outside micrometer': ['מיקרומטר חיצוני'],
  'depth micrometer': ['מיקרומטר עומק'],
  // Load Cell = מד כח (תא עומס בעברית), לא "עומס אלקטרוני".
  // הביטוי גובר על המילה הבודדת load→עומס.
  'load cell': ['מד כח', 'מדי כח', 'כח'],
  'loadcell': ['מד כח', 'מדי כח', 'כח'],
  'force gauge': ['מד כח', 'מדי כח', 'כח'],
  'force gage': ['מד כח', 'מדי כח', 'כח'],

  // טמפ' וזרימה
  // מ.ב.א. כותבים "תרמוקל" (לא תרמוקאפל) - חשוב להוסיף לתרגום
  'thermocouple type': ['תרמוקל', 'תרמוקאפל', 'זוג תרמואלקטרי', 'חוטי תרמוקל'],
  'thermocouple type k': ['תרמוקל K', 'תרמוקל', 'תרמוקאפל', 'חוטי תרמוקל'],
  'thermocouple type j': ['תרמוקל J', 'תרמוקל', 'תרמוקאפל'],
  'thermocouple type t': ['תרמוקל T', 'תרמוקל', 'תרמוקאפל'],
  thermocouple: ['תרמוקל', 'תרמוקאפל', 'חוטי תרמוקל'],
  thermocouples: ['תרמוקל', 'תרמוקאפל', 'חוטי תרמוקל'],
  // מ.ב.א. משתמשים ב-"Data Acquisition" (לא "data logger") לרישום נתונים
  'data logger': ['Data Acquisition', 'רשם נתונים'],
  'data acquisition': ['Data Acquisition', 'רשם נתונים'],
  'temperature data logger': ['Data Acquisition', 'תרמוקל', 'טמפרטורה'],
  'rtd sensor': ['חיישן RTD', 'חיישן טמפרטורה'],
  'platinum resistance': ['התנגדות פלטינה', 'pt100'],
  'pt100': ['pt100', 'חיישן טמפרטורה', 'התנגדות פלטינה'],
  'pt1000': ['pt1000', 'חיישן טמפרטורה'],
  'infrared thermometer': ['מד חום אינפרא אדום', 'אינפרא אדום'],
  'ir thermometer': ['מד חום אינפרא אדום'],
  'temperature controller': ['בקר טמפרטורה'],
  'temperature calibrator': ['מכייל טמפרטורה'],
  'temperature sensor': ['חיישן טמפרטורה'],
  'temperature probe': ['גשש טמפרטורה'],
  'electromagnetic flowmeter': ['מד ספיקת', 'מד ספיקה אלקטרומגנטי', 'מד ספיקה', 'מד זרימה אלקטרומגנטי'],
  'mass flow controller': ['בקר ספיקת מסה', 'ספיקת', 'ספיקה'],
  'mass flow meter': ['מד ספיקת מסה', 'ספיקת', 'ספיקה'],
  'flow controller': ['בקר ספיקה'],
  'flow indicator': ['מחוון ספיקה'],
  'flow probe': ['פרוב ספיקה', 'ספיקה'],
  'flow sensor': ['חיישן ספיקה'],
  'air flow': ['ספיקת אוויר', 'זרימת אוויר'],
  'water flow': ['ספיקת מים', 'זרימת מים'],

  // לחץ ואוויר
  'pressure gauge': ['מד לחץ', 'לחץ'],
  'pressure gage': ['מד לחץ', 'לחץ'],
  'pressure transmitter': ['משדר לחץ', 'לחץ'],
  'pressure transducer': ['מתמר לחץ', 'לחץ'],
  'pressure calibrator': ['מכייל לחץ', 'לחץ'],
  'pressure switch': ['מתג לחץ', 'לחץ'],
  'differential pressure': ['לחץ דיפרנציאלי', 'לחץ'],
  'vacuum gauge': ['מד ואקום', 'ואקום'],
  'vacuum pump': ['משאבת ואקום', 'ואקום'],
  'air compressor': ['מדחס אוויר'],
  'blower station': ['תחנת מפוח', 'מפוח'],

  // חשמל
  'electrical safety': ['בטיחות חשמלית', 'בטיחות'],
  'power supply': ['ספק כוח', 'מתח'],
  'power meter': ['מד הספק', 'הספק'],
  'function generator': ['גנרטור פונקציות'],
  'signal generator': ['גנרטור אותות'],
  'frequency counter': ['מונה תדר', 'תדר'],
  'frequency meter': ['מד תדר', 'תדר'],
  'frequency analyzer': ['מנתח תדר'],
  'clamp meter': ['מד אמפר מלחצת', 'מולטימטר מלחצת', 'מלחצת'],
  'clamp on': ['מלחצת'],
  'megohm meter': ['מד בידוד', 'מגר'],
  'ohm meter': ['מד התנגדות', 'אוממטר'],

  // מנופים, מנועים, יחידות
  'heat spreader': ['מפזר חום', 'חום'],
  'heat exchanger': ['מחליף חום'],
  // הסרנו את "פלטה" הבודדת - היא מתנגשת עם "פלטה לכיוון זוויות גלגלים"
  // ופלטות משטח. נשארות צורות מדויקות בלבד (פלטה חמה / קרה / מערבל).
  'cold plate': ['פלטה קרה'],
  'hot plate': ['פלטה חמה'],
  'hotplate with stirrer': ['פלטה חמה עם מערבל', 'מערבל'],
  'magnetic stirrer': ['מערבל מגנטי', 'מערבל'],
  'water bath': ['אמבט מים', 'אמבט'],
  'oil bath': ['אמבט שמן', 'אמבט'],
  'dry block': ['בלוק יבש', 'בלוק'],
  'dry well': ['בלוק יבש', 'בלוק'],
  'climatic chamber': ['תא אקלים', 'תא'],
  'environmental chamber': ['תא סביבתי', 'תא'],
  'humidity chamber': ['תא לחות', 'לחות'],
  'temperature chamber': ['תא טמפרטורה', 'תא'],

  // ציוד מעבדה
  'centrifuge tube': ['מבחנת צנטריפוגה'],
  'micro pipette': ['מיקרופיפטה', 'פיפטה'],
  'multichannel pipette': ['פיפטה רב-ערוצית', 'פיפטה'],
  'spectro photometer': ['ספקטרופוטומטר'],
  'analytical balance': ['מאזניים אנליטיים', 'מאזניים'],
  'precision balance': ['מאזניים מדויקים', 'מאזניים'],
  'platform scale': ['משקל פלטפורמה', 'משקל'],
  'bench scale': ['משקל שולחני', 'משקל'],
  'crane scale': ['משקל מנוף', 'משקל'],

  // אבזרים מכניים
  'torque wrench': ['מפתח מומנט', 'מומנט'],
  'torque meter': ['מד מומנט', 'מומנט'],
  'torque tester': ['בודק מומנט', 'מומנט'],
  'weight set': ['סט משקולות', 'משקולות'],
  'test weights': ['משקולות בדיקה', 'משקולות'],
  'standard weights': ['משקולות תקן', 'משקולות'],
  'radial jig': ['ג׳יג רדיאלי', 'ג׳יג'],
  'magnet radial': ['מגנט רדיאלי', 'מגנט'],
};

// מילים בודדות
const EN_WORDS_TO_HE: Record<string, string[]> = {
  // מכשירי מדידה
  // מ.ב.א. משתמשים ב-"זחון" כמונח עיקרי ל-caliper (12 פריטים במחירון).
  caliper: ['זחון', 'קליבר'],
  calipers: ['זחון', 'קליבר'],
  micrometer: ['מיקרומטר'],
  thermometer: ['מד חום', 'מד טמפ', 'טרמומטר'],
  multimeter: ['מולטימטר'],
  oscilloscope: ['אוסילוסקופ'],
  voltmeter: ['מד מתח'],
  ammeter: ['מד זרם'],
  ohmmeter: ['מד התנגדות', 'אוממטר'],
  manometer: ['מנומטר', 'מד לחץ'],
  hygrometer: ['מד לחות'],
  anemometer: ['מד רוח'],
  tachometer: ['טכומטר', 'מד סיבובים'],
  viscometer: ['מד צמיגות'],
  refractometer: ['רפרקטומטר', 'מד שבירה'],
  spectrophotometer: ['ספקטרופוטומטר'],
  dynamometer: ['דינמומטר', 'מד כוח'],
  durometer: ['דורומטר', 'מד קושי'],
  megohmmeter: ['מד בידוד', 'מגר'],
  megger: ['מד בידוד', 'מגר'],
  // מ.ב.א. אומרים "מד ספיקה" (לא "מד זרימה"). מוסיפים גם "ספיקת" (סמיכות)
  // כי הם כותבים "מד ספיקת גזים" - בלעדי זה אין התאמה.
  rotameter: ['מד ספיקה', 'מד ספיקת', 'מד זרימה', 'רוטמטר'],
  flowmeter: ['מד ספיקה', 'מד ספיקת', 'מד זרימה'],
  flowprobe: ['מד ספיקה', 'מד ספיקת', 'מד זרימה', 'פרוב ספיקה'],
  pyrometer: ['פירומטר'],
  barometer: ['ברומטר'],
  hydrometer: ['הידרומטר'],
  conductometer: ['מד מוליכות'],
  potentiometer: ['פוטנציומטר'],
  galvanometer: ['גלוונומטר'],
  wattmeter: ['ואטמטר', 'מד הספק'],
  thermocouple: ['תרמוקאפל', 'זוג תרמואלקטרי'],
  rtd: ['rtd', 'חיישן טמפרטורה'],

  // מכשירי בדיקה
  tester: ['בודק'],
  indicator: ['מחוון'],
  detector: ['גלאי'],
  analyzer: ['מנתח'],
  controller: ['בקר'],
  calibrator: ['מכייל'],
  transmitter: ['משדר'],
  transducer: ['מתמר'],
  receiver: ['מקלט'],
  recorder: ['רשם', 'רשמקול'],
  logger: ['לוגר', 'רשם'],

  // מדדי כיול - לא מתרגמים "gauge"/"meter" סתם כי הם הופכים ל"מד" גנרי
  // שמתאים לכל פריט עברי שמכיל "מד" - מה שיוצר התאמות שווא.
  // אם צריך "מד" - יש ביטוי-מילים תואם (pressure gauge, pin gauge וכד').
  probe: ['פרוב', 'גשש'],
  sensor: ['חיישן'],

  // תכונות נמדדות. מוסיפים גם צורת סמיכות (ספיקת, זרימת) להתאמה לכותרות במחירון.
  pressure: ['לחץ'],
  flow: ['ספיקה', 'ספיקת', 'זרימה', 'זרימת'],
  thickness: ['עובי'],
  temperature: ['טמפ', 'טמפרטורה', 'חום'],
  humidity: ['לחות'],
  conductivity: ['מוליכות'],
  resistance: ['התנגדות'],
  voltage: ['מתח'],
  current: ['זרם'],
  power: ['הספק'],
  energy: ['אנרגיה'],
  frequency: ['תדר'],
  capacitance: ['קיבול'],
  inductance: ['השראות'],
  torque: ['מומנט'],
  hardness: ['קושי'],
  insulation: ['בידוד'],
  vacuum: ['ואקום'],
  weight: ['משקל', 'משקולת'],
  weights: ['משקולות'],
  mass: ['מסה'],
  depth: ['עומק'],
  height: ['גובה'],
  length: ['אורך'],
  width: ['רוחב'],
  volume: ['נפח'],
  area: ['שטח'],
  velocity: ['מהירות'],
  speed: ['מהירות'],
  acceleration: ['תאוצה'],
  density: ['צפיפות'],
  viscosity: ['צמיגות'],
  ph: ['pH', 'חומציות'],

  // ציוד מעבדה
  balance: ['מאזניים', 'משקל'],
  scale: ['משקל', 'מאזניים'],
  scales: ['משקל', 'מאזניים'],
  hotplate: ['פלטה חמה'],
  stirrer: ['מערבל'],
  agitator: ['מערבל'],
  shaker: ['שייקר', 'רועד'],
  oven: ['תנור'],
  furnace: ['תנור'],
  incubator: ['אינקובטור'],
  centrifuge: ['צנטריפוגה'],
  pipette: ['פיפטה'],
  pipettes: ['פיפטות'],
  pipet: ['פיפטה'],
  microscope: ['מיקרוסקופ'],
  autoclave: ['אוטוקלב'],
  chamber: ['תא'],
  bath: ['אמבט'],
  desiccator: ['דסיקטור'],

  // אביזרים מכניים
  ruler: ['סרגל'],
  level: ['פלס'],
  protractor: ['פרוטרקטור'],
  square: ['מד זוויות', 'זווית'],
  wrench: ['מפתח'],
  screwdriver: ['מברג'],
  driver: ['מברג'],
  pliers: ['פלייר', 'צבת'],

  // עזרים
  set: ['סט', 'ערכה'],
  kit: ['ערכה', 'סט'],
  vernier: ['ורנייר'],
  digital: ['דיגיטלי'],
  analog: ['אנלוגי'],
  analogue: ['אנלוגי'],
  electronic: ['אלקטרוני'],
  mechanical: ['מכני'],
  precision: ['דיוק', 'מדויק'],
  portable: ['נייד'],
  handheld: ['ידני'],
  bench: ['שולחני'],

  // חלקים מכניים / יחידות
  pump: ['משאבה'],
  motor: ['מנוע'],
  valve: ['שסתום'],
  compressor: ['מדחס'],
  blower: ['מפוח'],
  fan: ['מאוורר'],
  heater: ['מחמם'],
  cooler: ['מצנן'],
  chiller: ['צ׳ילר', 'מצנן'],
  unit: ['יחידה'],
  system: ['מערכת'],
  station: ['תחנה'],
  jig: ['ג׳יג'],
  fixture: ['תפסנית', 'ג׳יג'],
  adapter: ['מתאם'],
  magnet: ['מגנט'],

  // טכנולוגיות
  ultrasonic: ['אולטרסוני'],
  electromagnetic: ['אלקטרומגנטי'],
  electrical: ['חשמלי'],
  electric: ['חשמלי'],
  pneumatic: ['פנאומטי'],
  hydraulic: ['הידראולי'],
  thermal: ['תרמי'],
  optical: ['אופטי'],

  // מצבי דיוק / רמה
  standard: ['תקן'],
  reference: ['התייחסות', 'תקן'],
  calibration: ['כיול'],
  measurement: ['מדידה'],
  test: ['בדיקה'],
  testing: ['בדיקה'],
  safety: ['בטיחות'],

  // יחידות נפוצות
  bar: ['בר'],
  psi: ['psi'],
  mpa: ['mpa'],
  newton: ['ניוטון'],
  celsius: ['צלזיוס'],
  fahrenheit: ['פרנהייט'],
  kelvin: ['קלווין'],

  // מכשירים נוספים
  timer: ['טיימר', 'שעון עצר'],
  stopwatch: ['סטופר', 'שעון עצר'],
  counter: ['מונה'],
  monitor: ['צג'],
  display: ['תצוגה'],
  amplifier: ['מגבר'],
  generator: ['גנרטור'],
  spectrum: ['ספקטרום'],
  extensometer: ['אקסטנסומטר', 'מד תזוזה'],
  extension: ['התרחבות'],
  strain: ['מאמץ', 'דפורמציה'],
  load: ['עומס'],
  cell: ['תא'],
  displacement: ['תזוזה'],
  inclinometer: ['מד הטיה'],
  clinometer: ['מד הטיה'],
  level_meter: ['מד מפלס'],
  flowstation: ['תחנת זרימה'],
  encoder: ['קודן'],

  // חלקים נמדדים
  pin: ['פין'],
  pins: ['פינים'],
  shaft: ['ציר'],
  bearing: ['מיסב'],
  spring: ['קפיץ'],

  // התעתיק העברי לשמות מותגים נפוצים
  fluke: ['פלוק'],
  mitutoyo: ['מיטוטויו'],
  omega: ['אומגה'],
  agilent: ['אגילנט'],
  keysight: ['קייסייט'],
  tektronix: ['טקטרוניקס'],
  transonic: ['טרנסוניק'],
  zumbach: ['צומבך'],
  mettler: ['מטלר'],
  mahr: ['מאר'],
  starrett: ['סטארט'],
  sartorius: ['סרטוריוס'],
  ohaus: ['אוהאוס'],
  shimadzu: ['שימדזו'],
  endress: ['אנדרס'],
  hauser: ['האוזר'],
};

// caching: כל שאילתה מתורגמת פעם אחת בלבד
const cache = new Map<string, string>();

// סורט אורד ביטויי-מילים לפי אורך (ארוכים קודם) כדי שתת-ביטוי לא יתפס לפני ההורד המקיף שלו
const sortedPhrases = Object.keys(EN_PHRASES_TO_HE).sort((a, b) => b.length - a.length);

/**
 * מוסיף תרגום עברי של מונחים אנגליים נפוצים אל השאילתה.
 * אם אין מונח באנגלית - מחזיר את השאילתה ללא שינוי.
 */
export function enrichWithTranslations(query: string): string {
  if (!query) return query;
  const cached = cache.get(query);
  if (cached !== undefined) return cached;

  const lower = query.toLowerCase();
  const additions = new Set<string>();

  // 1. ביטויי-מילים (ארוכים קודם)
  for (const phrase of sortedPhrases) {
    if (lower.includes(phrase)) {
      for (const he of EN_PHRASES_TO_HE[phrase]) additions.add(he);
    }
  }

  // 2. מילים בודדות
  for (const [en, hes] of Object.entries(EN_WORDS_TO_HE)) {
    const re = new RegExp(`(^|[^a-z0-9])${en.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^a-z0-9]|$)`, 'i');
    if (re.test(lower)) {
      for (const he of hes) additions.add(he);
    }
  }

  const result = additions.size === 0 ? query : `${query} ${[...additions].join(' ')}`;
  cache.set(query, result);
  return result;
}

/**
 * בדיקה אם הוספנו תרגומים (כדי לדעת אם להריץ מחדש את המאצ'ר).
 */
export function hasEnrichment(original: string, enriched: string): boolean {
  return enriched.length > original.length;
}
