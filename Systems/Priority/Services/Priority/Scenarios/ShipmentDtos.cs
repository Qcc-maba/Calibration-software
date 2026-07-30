namespace Maba.Api.Services.Priority.Scenarios;

/// <summary>One quantity override on a shipment detail line (docx steps 7-8, e.g. סנמינה).</summary>
public record ShipmentQuantityUpdate(
    string PartName,    // מק"ט, e.g. "130801-0"
    decimal Quantity    // הכמות החדשה
);

/// <summary>
/// Inputs for Scenario 2 — "הוצאת תעודת משלוח" (customer shipment, ביקורת station).
/// Covers the 4 docx variants: full / partial (DeviceFilters) / no billing (Billing=false)
/// / quantity+extra-charge updates (QuantityUpdates).
/// </summary>
public record ShipmentRequest(
    string CustomerName,        // מס. לקוח, e.g. "439"
    string IntakeDoc,           // תעודת קליטה, e.g. "2601048"
    string? Contact = null,     // איש קשר (ריק = לא מעדכנים)
    // אילו מכשירים לסמן. ריק/null = כולם. כל ערך מושווה מול: תאור מכשיר,
    // מספר מוטבע (סידורי), מס' קריאת שרות, מספר מבא.
    IReadOnlyList<string>? DeviceFilters = null,
    bool Billing = true,        // false = להוריד את ה-V לחיוב מכל שורות הפירוט
    IReadOnlyList<ShipmentQuantityUpdate>? QuantityUpdates = null,
    // כשtrue: שורות חיוב (פיטור/תחזוקה/סט) מקבלות כמות = יתרה למשלוח (CQUANT); ומכשירים
    // מאותו מק"ט מקובצים לשורה אחת (כמות = מספר המכשירים) והשורות הכפולות נמחקות (כולל
    // מחיקת קישורי קריאת השרות). מק"ט עם עדכון מפורש ב-QuantityUpdates גובר. לפני "סופית".
    bool AutoQuantities = true,
    string? FreeText = null,    // טקסט חופשי (למשל "משלוח חלקי")
    bool Finalize = true        // סטטוס → סופית (חייב אחרי עדכוני כמות!)
);
