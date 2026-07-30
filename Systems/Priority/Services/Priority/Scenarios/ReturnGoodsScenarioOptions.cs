namespace Maba.Api.Services.Priority.Scenarios;

/// <summary>
/// Entity (Priority screen internal-name) and field names for the
/// "Return of Goods from Customer / external calibration" scenario.
///
/// Discovered from the live $metadata (env s190225, 2026-07):
/// the document is Priority screen <b>DOCUMENTS_N</b> ("החזרות סחורה מלקוח").
/// ✓ = confirmed from $metadata. ❓ = still needs verification once DOCUMENTS_N
/// is opened to the API license (currently "לא ניתן להפעיל API למסך זה").
///
/// Binds from config section "PriorityScenarios:ReturnGoods".
/// See docs/scenarios/return-goods-external-calibration.md.
/// </summary>
public class ReturnGoodsScenarioOptions
{
    // ── Entities (Priority screens / forms) ──────────────────────────
    public string OrdersEntity { get; set; }        = "ORDERS";                // הזמנת לקוח (verify API-open)
    public string ReturnDocEntity { get; set; }     = "DOCUMENTS_N";           // ✓ החזרת סחורה מלקוח (header)
    public string ReturnLinesSubform { get; set; }  = "TRANSORDER_N_SUBFORM";  // ✓ פירוט — detail lines (auto-created by marking order lines)
    public string OrderLinkSubform { get; set; }    = "MBA_DOCORD_SUBFORM";    // ✅ link an order to the doc (POST {ORDNAME})
    public string OrderLinesSelectSubform { get; set; } = "MBA_DOCORDI_SUBFORM"; // ✅ בחירת שורות הזמנה — marking FLAG='Y' auto-creates the detail line
    public string OrderLineFlagField { get; set; }  = "FLAG";                  // ✅ mark checkbox
    public string OrderLineKey1 { get; set; }       = "ORD";                   // ✅ MBA_DOCORDI composite key part 1
    public string OrderLineKey2 { get; set; }       = "KLINE";                 // ✅ MBA_DOCORDI composite key part 2
    public string OrderLineSkuField { get; set; }   = "PARTNAME";              // ✅ מק"ט (to match against req.Skus)

    // ── Contact resolution: main contact of the customer ─────────────
    public string ContactSourceEntity { get; set; }    = "PERSONNELLOAD";     // ✅ contacts (open)
    public string ContactSourceCustField { get; set; } = "CUSTNAME";
    public string ContactMainFlagField { get; set; }   = "MAINPHONE";         // ✅ 'Y' marks the main contact
    public string ContactMainFlagValue { get; set; }   = "Y";
    public string ContactSourceNameField { get; set; } = "NAME";
    // ✅ VERIFIED via metadata Hebrew annotation: MBA_DOC_N_USERS_SUBFORM = "כיילים לקליטה (כיולי חוץ)"
    public string CalibratorsSubform { get; set; }  = "MBA_DOC_N_USERS_SUBFORM"; // ✅ כיילים לקליטה
    // ✅ Calibrators live in USERS where GROUPNAME='kayalim' (open). Resolve name→USERID,
    //    then POST {USERID, SNAME} to the calibrators sub-form. (e.g. משה כץ=136, ערן שבח=48)
    public string CalibratorMasterEntity { get; set; } = "USERS";
    public string CalibratorGroupField { get; set; }   = "GROUPNAME";
    public string CalibratorGroupName { get; set; }    = "kayalim";
    // ✅ VERIFIED live: sub-form USERID == USERS.BUSERID (NOT USERS.USERID). e.g. ערן שבח=535, משה כץ=58
    public string CalibratorMasterIdField { get; set; }   = "BUSERID";
    public string CalibratorMasterNameField { get; set; } = "SNAME";
    public string DeviceNumbersSubform { get; set; }= "MBA_SCANSERN_SUBFORM";  // ✓ רישום מספרי מכשירים (NEWMBANUM/SERNUM/MNFDES/MODEL/CALIBMONTH)

    // ── Header fields (all ✓ from DOCUMENTS_N metadata) ──────────────
    public string DocKeyField { get; set; }         = "DOCNO";               // ✓ מספר תעודה (returned by POST)
    public string OrderNumField { get; set; }       = "ORDNAME";             // ✓ מספר הזמנה
    public string CustField { get; set; }           = "CUSTNAME";            // ✓ לקוח
    public string SiteField { get; set; }           = "BRANCHNAME";          // ✓ אתר
    public string ContactField { get; set; }        = "NAME";                // ❓ איש קשר (header NAME; or DOCUMENTS_DCONT subform)
    public string ExternalCalibFlagField { get; set; } = "ZMBA_CALIBERATION"; // ✓ כיול חוץ (Edm.String)
    public string ExternalCalibFlagValue { get; set; } = "Y";                // ✅ VERIFIED — real docs use 'Y'
    public string CalibDateField { get; set; }      = "MBA_CALRETDATE";      // ✓ תאריך כיול
    public string DocumentDateField { get; set; }   = "CURDATE";             // ✅ שדה "תאריך" בכותרת (מתאריך יצירה כברירת מחדל — צריך override)
    public string IntakeTextField { get; set; }     = "MBA_TEXT";            // ✓ טקסט לקליטה
    public string StatusField { get; set; }         = "STATDES";             // ✓ סטטוס (description; codes in DOCSTAT/MBA_STCODE)

    // ── Line (detail) fields — from TRANSORDER_N_SUBFORM ─────────────
    public string LineOrderNumField { get; set; }   = "ORDNAME";             // ✓ מספר הזמנה בשורה
    public string LineSkuField { get; set; }        = "PARTNAME";            // ✓ מק"ט
    public string LineQuantityField { get; set; }   = "QUANT";               // ✓ כמות
    public string LineCalibRangeField { get; set; } = "";                    // ❓ תחום כיול per-line (range is header-level MBA_TEXT/ZMBA)

    public string CalibratorNameField { get; set; } = "SNAME";               // ✅ שם עובד/כייל (in MBA_DOC_N_USERS)
    public string CalibratorEmpIdField { get; set; } = "USERID";             // ✅ מס. עובד (employee number; resolved from EMPLOYEES/TECHNICIANS)

    // ── Composite document key: DOCUMENTS_N key = (DOCNO, TYPE), TYPE='N' ─
    public string DocTypeField { get; set; }         = "TYPE";
    public string DocTypeValue { get; set; }         = "N";

    // ── Status values (STATDES) — ✅ VERIFIED against real documents ──
    public string StatusDraft { get; set; }          = "טיוטא";      // ✅ (58 docs)
    public string StatusInExternalCalib { get; set; } = "בכיול חוץ"; // ✅ (68 docs)

    // ── Service call (step 17) — ✅ created DIRECTLY (bypasses the thick-client
    //    dummy-instrument/load/delete dance which OData can't replicate). ──
    public bool CreateServiceCall { get; set; }      = true;
    public string ServiceCallEntity { get; set; }    = "DOCUMENTS_Q";       // ✅ קריאות שרות
    public string InstrumentEntity { get; set; }     = "SERNUMBERS";        // ✅ כרטיס מכשיר
    public string InstrumentSerialField { get; set; } = "SERNUM";           // ✅ מס' מכשיר = "<cust>-<serial>"
    public string InstrumentPartField { get; set; }   = "PARTNAME";
    public string InstrumentCustField { get; set; }   = "CUSTNAME";
    public string DummyPartName { get; set; }         = "999999";           // מק"ט דמה "קליטת פריט לצורך קריאת שרות"
    public string DummySerial { get; set; }           = "002";              // מספר סידורי דמה (per customer)
    // Service-call fields (POST body) — verified live on A260000016
    public string CallCustField { get; set; }         = "CUSTNAME";
    public string CallPartField { get; set; }         = "PARTNAME";
    public string CallSerialField { get; set; }       = "SERNUM";           // "<cust>-<serial>"
    public string CallReturnDocField { get; set; }    = "MBA_DOCNO_N";      // ✅ מקשר לתעודת ההחזרה
    public string CallMbaNumField { get; set; }       = "MBA_MBANUM";       // "<docno>/999"
    public string CallMbaPrefix { get; set; }         = "999";
    public string CallStatusField { get; set; }       = "CALLSTATUSCODE";
    public string CallStatusReceived { get; set; }    = "נקלט";
    public string CallExtCalibField { get; set; }     = "MBA_OUTCALIB";
    public string CallExtCalibValue { get; set; }     = "Y";
    public string InstrumentIdField { get; set; }     = "SERN";             // returned internal id (unused here but handy)
    // DOCUMENTS_Q composite key = (DOCNO, TYPE='Q') — for reading the call back.
    public string CallKeyField { get; set; }          = "DOCNO";
    public string CallTypeField { get; set; }         = "TYPE";
    public string CallTypeValue { get; set; }         = "Q";

    // ── Literal device registration (docx steps 13–16) ──────────────
    // Replicates the manual thick-client flow verbatim (verified live on s190225):
    //   13. add a dummy detail line "999999-7" in TRANSORDER_N_SUBFORM
    //   14. tab "רישום מספרי מכשירים" = MBA_SCANSERN_SUBFORM
    //   15. serial 002  → SERNUM resolves to "<cust>-002" (the device's SERN id is required)
    //   16. "מספר מבא" = 999 → NEWMBANUM
    // The service call itself (step 17) is still created directly in step 6b — OData does
    // not auto-create it from this registration alone.
    public bool LiteralDeviceRegistration { get; set; } = true;
    public string DummyLinePart { get; set; }         = "999999-7";           // ✅ step 13 detail line (מק"ט דמה)
    public long DummyPartId { get; set; }             = 5059;                 // ✅ SERNUMBERS.PART internal id of "999999"
    public string DeviceRegSubform { get; set; }      = "MBA_SCANSERN_SUBFORM"; // ✅ רישום מספרי מכשירים
    public string DeviceRegIdField { get; set; }      = "MBA_SERN";           // ✅ required: device internal id (= SERNUMBERS.SERN)
    public string DeviceRegSerialField { get; set; }  = "SERNUM";             // ✅ resolves to "<cust>-002"
    public string DeviceRegMbaField { get; set; }     = "NEWMBANUM";          // ✅ "מספר מבא"
    public string DeviceRegMbaValue { get; set; }     = "999";                // ✅ step 16 value

    // ── Cleanup / cancel (docx steps 18–19) — ✅ verified live on s190225 ──
    //   18. delete the serial registration (MBA_SCANSERN row) → cancel the service call (17)
    //   19. delete the dummy "999999-7" detail line
    public bool CleanupDummy { get; set; }            = true;
    public string CallCancelStatus { get; set; }      = "מבוטלת";             // ✅ step 18 CALLSTATUSCODE
    public string ReturnLineKeyField { get; set; }    = "KLINE";              // ✅ TRANSORDER_N key part (with TYPE='N')

    // ── Read-back verification ───────────────────────────────────────
    // When true, every write is re-read and compared field-by-field to what was sent.
    // Adds one GET per write; turn off in production for speed.
    public bool VerifyWrites { get; set; }            = true;
}
