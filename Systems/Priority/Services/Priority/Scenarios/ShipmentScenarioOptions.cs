namespace Maba.Api.Services.Priority.Scenarios;

/// <summary>
/// Entity/field names for Scenario 2 — "הוצאת תעודת משלוח" (customer shipment from an
/// intake doc, ביקורת station). All ✅ verified live on s190225 (doc D26000004, 2026-07):
///   1-2. POST DOCUMENTS_D {CUSTNAME}                  → new shipment, TYPE='D', status טיוטא
///   3.   PATCH {NAME}                                 → contact
///   4.   POST MBA_DOC_N_SUBFORM {DOCNO}               → link intake; auto-fills device list
///   5.   PATCH MBA_CALLSTODOC_DSEND(LINE,USER) {SENT:'Y'} → mark device; the row is CONSUMED
///        (keys shift!) so we re-read the subform after every mark.
///   6.   GET TRANSORDER_D_SUBFORM                     → detail lines auto-created
///   7.   PATCH TRANSORDER_D(KLINE,TYPE='D') {TQUANT}  → quantities (BEFORE finalize only)
///        PATCH {FLAG:null}                            → drop billing V
///   8.   POST DOCUMENTSTEXT_SUBFORM {TEXT,APPEND}     → free text
///   9.   PATCH {STATDES:'סופית'}                      → finalize
/// Binds from config section "PriorityScenarios:Shipment".
/// </summary>
public class ShipmentScenarioOptions
{
    // ── Shipment document (משלוחים ללקוח) ────────────────────────────
    public string ShipDocEntity { get; set; }      = "DOCUMENTS_D";
    public string DocKeyField { get; set; }        = "DOCNO";
    public string DocTypeField { get; set; }       = "TYPE";
    public string DocTypeValue { get; set; }       = "D";
    public string CustField { get; set; }          = "CUSTNAME";     // מס. לקוח
    public string ContactField { get; set; }       = "NAME";         // איש קשר
    public string StatusField { get; set; }        = "STATDES";
    public string StatusFinal { get; set; }        = "סופית";

    // ── Intake link (תעודות קליטה למשלוח) ────────────────────────────
    public string IntakeLinkSubform { get; set; }  = "MBA_DOC_N_SUBFORM";
    public string IntakeDocField { get; set; }     = "DOCNO";        // תעודת קליטה

    // ── Device marking (סימון מכשירים לתעודה) ────────────────────────
    public string MarkSubform { get; set; }        = "MBA_CALLSTODOC_DSEND_SUBFORM";
    public string MarkKey1 { get; set; }           = "LINE";
    public string MarkKey2 { get; set; }           = "USER";
    public string MarkSentField { get; set; }      = "SENT";         // 'Y' = selected (row consumed)
    public string MarkSerialDescField { get; set; } = "SERNDES";     // תאור מכשיר
    public string MarkStampField { get; set; }     = "FREE1";        // מספר מוטבע (serial)
    public string MarkCallField { get; set; }      = "DOCNO";        // ק. שרות
    public string MarkMbaNumField { get; set; }    = "NUM";          // מספר מבא
    public int MarkMaxIterations { get; set; }     = 60;             // re-read loop safety cap

    // ── Detail lines (משלוחים ללקוח - פירוט) ─────────────────────────
    public string DetailSubform { get; set; }      = "TRANSORDER_D_SUBFORM";
    public string LineKeyField { get; set; }       = "KLINE";
    public string LineSkuField { get; set; }       = "PARTNAME";
    public string LineQtyField { get; set; }       = "TQUANT";       // כמות (בפועל למשלוח)
    public string LineBalanceField { get; set; }   = "CQUANT";       // יתרה למשלוח (המקור לשורת חיוב)
    public string LineBillingField { get; set; }   = "FLAG";         // לחיוב ('Y' / null)
    // רישום מספרי מכשירים לכל שורה — שורה עם ערך כאן היא "שורת מכשיר".
    public string DeviceRegPerLineSubform { get; set; } = "SERNTRANS_SUBFORM";
    public string DeviceRegKeyField { get; set; }       = "SERN";      // מפתח SERNTRANS (ID מכשיר)
    public string DeviceRegNumField { get; set; }       = "SERNUM";    // מס' מכשיר (להוספת סידורי לשורה)
    // קריאות שרות למכשיר — חוסמות מחיקת סידורי; מוחקים אותן קודם.
    public string DeviceCallLinkSubform { get; set; }   = "MBA_SERNTRANSCALL_SUBFORM";
    public string DeviceCallKeyField { get; set; }      = "CALL";
    // קיבוץ מכשירים: לאחד את כל מכשירי אותו מק"ט לשורה אחת (כמות = מספר המכשירים)
    // ולמחוק את השורות הכפולות. destructive — דורש הרשאת מחיקה למסך.
    public bool GroupDevices { get; set; }              = true;

    // ── Free text (טקסט חופשי) ───────────────────────────────────────
    public string TextSubform { get; set; }        = "DOCUMENTSTEXT_SUBFORM";
    public string TextField { get; set; }          = "TEXT";
    public string TextAppendField { get; set; }    = "APPEND";
}
