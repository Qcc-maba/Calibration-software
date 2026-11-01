/*
    Seed-PredefinedRemarks                                                                 MBA-848
    ---------------------------------------------------------------------------------------------
    Loads dbo.PredefinedRemarks from Nofar's Excel, "הערות.xlsx" on MBA-848 (attachment 25537,
    61 remarks). Worksheet -> sub-domain, as Nofar mapped them on 01/11:

        chambers  -> תאים           Report remarks
        cycle     -> תאים           Cycle remarks (chamber cycles only)
        sensors   -> רגשים          Report remarks
        vehicles  -> משאיות קירור   Report remarks (the flow is not built yet; the rows wait for it)

    The sub-domain is resolved by dbo.SecondaryCategories.SecondaryCategoryName, never by id, so the
    file works on STAGE and PROD alike. DisplayOrder is the Excel row order, in steps of 10.

    Each '*' became a numbered placeholder ({1}, {2}, ... in order of appearance) with an empty
    default, which the calibrator must fill. Changed beyond that, for Nofar to confirm:
      - PID (chambers and sensors): the Excel row is garbled - the Hebrew is in visual order with
        three '*', the English has one. Both are now "P={1}, I={2}, D={3}".
      - cycle "טמפרטורת עיקור": 121.1 and 15 are values with those defaults.
      - cycle "רגשים מ 1 עד 10": 1 and 10 are values with those defaults.
      - sensors emissivity: 0.95 is a value with that default.
      - cycle "זמן התאוששות ... והינו:" and sensors "...עם המקדמים הבאים:" end in a colon, so a
        value {1} now follows it.

    Inserts only what is missing - matched on (sub-domain, Scope, TextHEB) - and never rewrites a row:
    a row in use is retired with IsActive = 0 and replaced, not edited (dbo.PredefinedRemarks).
    A row that matches on the Hebrew but differs in anything else is reported as 'Differs' and left
    alone.

    @Apply = 0 (default) reports; @Apply = 1 inserts. A second run reports zero inserts.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = 0;

DECLARE @Seed TABLE
(
    SecondaryCategoryName NVARCHAR(100)  NOT NULL,
    Scope                 NVARCHAR(10)   NOT NULL,
    DisplayOrder          INT            NOT NULL,
    TextHEB               NVARCHAR(1000) NOT NULL,
    TextENG               NVARCHAR(1000) NOT NULL,
    DefaultValues         NVARCHAR(1000) NULL
);

INSERT @Seed (SecondaryCategoryName, Scope, DisplayOrder, TextHEB, TextENG, DefaultValues)
VALUES
    (N'תאים', N'Report', 10, N'רגש מס'' {1} הוצב צמוד לרגש ניטור הטמפרטורה.', N'Sensor No. {1} positioned next to the temperature control sensor.', N'[""]'),
    (N'תאים', N'Report', 20, N'מרווח דגימת הנתונים כל {1} שניות.', N'Data sampling interval: every {1} seconds.', N'[""]'),
    (N'תאים', N'Report', 30, N'טמפרטורות הבדיקה, מספר ומיקום נקודות הבדיקה - בתאום עם הלקוח.', N'Test temperatures, number, and location of test points coordinated with the customer.', NULL),
    (N'תאים', N'Report', 40, N'נתוני ה-PID כפי שמוגדרים בבקר: P={1}, I={2}, D={3}', N'PID data as defined in the controller: P={1}, I={2}, D={3}', N'["", "", ""]'),
    (N'תאים', N'Report', 50, N'בוצע כיוון.', N'Adjustment performed.', NULL),
    (N'תאים', N'Report', 60, N'ראה תוצאות לפני ואחרי כיוון', N'See results before and after adjustment.', NULL),
    (N'תאים', N'Report', 70, N'בוצע תיקון', N'Repair performed.', NULL),
    (N'תאים', N'Report', 80, N'בוצע כיוון לבקר.', N'Controller adjustment performed.', NULL),
    (N'תאים', N'Report', 90, N'בוצע כיוון לתצוגה.', N'Display adjustment performed.', NULL),
    (N'תאים', N'Report', 100, N'בקר הגנת טמפרטורת יתר נבדק ונמצא תקין.', N'Over-temperature protection controller tested and found compliant.', NULL),
    (N'תאים', N'Cycle', 10, N'נבדק עם מטען.', N'Tested under loaded conditions.', NULL),
    (N'תאים', N'Cycle', 20, N'נבדק ללא מטען.', N'Tested under no-load conditions', NULL),
    (N'תאים', N'Cycle', 30, N'נבדק כאשר הארובה פתוחה.', N'Tested with vent open.', NULL),
    (N'תאים', N'Cycle', 40, N'נבדק כאשר הארובה סגורה.', N'Tested with vent closed.', NULL),
    (N'תאים', N'Cycle', 50, N'נבדק כאשר האולטרסוני כבוי.', N'Tested with ultrasonic off.', NULL),
    (N'תאים', N'Cycle', 60, N'נבדק עם ואקום.', N'Tested under vacuum.', NULL),
    (N'תאים', N'Cycle', 70, N'נבדק ללא ואקום.', N'Tested without vacuum.', NULL),
    (N'תאים', N'Cycle', 80, N'תצוגת הטמפרטורה במדפסת ובצג זהה.', N'Temperature readings on printer and display are identical.', NULL),
    (N'תאים', N'Cycle', 90, N'תצוגת הלחץ במדפסת ובצג זהה.', N'Pressure readings on printer and display are identical.', NULL),
    (N'תאים', N'Cycle', 100, N'טמפרטורת עיקור ℃{1}, זמן עיקור {2} דקות.', N'Sterilization temperature: {1}℃, sterilization time: {2} minutes.', N'["121.1", "15"]'),
    (N'תאים', N'Cycle', 110, N'בוצע כיוון לבקר.', N'Controller adjustment performed.', NULL),
    (N'תאים', N'Cycle', 120, N'בוצע כיוון לתצוגה.', N'Display adjustment performed.', NULL),
    (N'תאים', N'Cycle', 130, N'רגשים מ {1} עד {2} נמצאים בתוך המטען במקומם המקורי.', N'Sensors {1} to {2} are placed inside the load in their original positions.', N'["1", "10"]'),
    (N'תאים', N'Cycle', 140, N'זמן התאוששות (RECOVERY) שנמדד הינו מהגעת הרגש הראשון לתחום הטמפרטורה ועד להגעת הרגש האחרון, והינו: {1}', N'Recovery time is measured from when the first sensor enters the target temperature range until the last sensor stabilizes. Measured recovery time: {1}', N'[""]'),
    (N'תאים', N'Cycle', 150, N'"המונח OVERSHOOT מתייחס לטמפרטורה המקסימלית לפני התייצבות."', N'The term "overshoot" refers to maximum temperature before stabilization.', NULL),
    (N'רגשים', N'Report', 10, N'נלקחו קריאות ב-OHM ובוצע חישוב מתמטי למעלות ℃ לפי טבלה ASTM E1137.', N'Readings taken in OHMs and mathematically converted to ℃ per ASTM E1137 table.', NULL),
    (N'רגשים', N'Report', 20, N'נלקחו קריאות ב-OHM ובמעלות ℃.', N'Readings taken in OHMs and degrees ℃.', NULL),
    (N'רגשים', N'Report', 30, N'נלקחו קריאות ב-mV ובוצע חישוב מתמטי למעלות ℃ לפי טבלה ASTM E230.', N'Readings taken in mV and mathematically converted to ℃ per ASTM E230 table.', NULL),
    (N'רגשים', N'Report', 40, N'קריאה נלקחה באמצעות מכשיר מדידה של מ.ב.א.', N'Reading taken using an QCC measuring instrument.', NULL),
    (N'רגשים', N'Report', 50, N'קריאה נלקחה באמצעות מכשיר {1} בערוץ {2}.', N'Reading taken using instrument {1} on channel {2}.', N'["", ""]'),
    (N'רגשים', N'Report', 60, N'ערכי המדידה המוצגים בעמודת "ערך מדוד" כוללים את ה-OFFSET המוגדר בבקר/רשם.', N'Measurement values in the "Measured Value" column include the controller/recorder OFFSET.', NULL),
    (N'רגשים', N'Report', 70, N'OFFSET = {1}', N'OFFSET = {1}', N'[""]'),
    (N'רגשים', N'Report', 80, N'בוצעה בדיקת רגישות (SENSETIVITY) ונמצאה תקינה.', N'Sensitivity test performed and found compliant.', NULL),
    (N'רגשים', N'Report', 90, N'הערך הנומינלי מוצג לאחר קיזוז סטיות.', N'Nominal value displayed after deviation compensation.', NULL),
    (N'רגשים', N'Report', 100, N'נתוני ה-PID כפי שמוגדרים בבקר: P={1}, I={2}, D={3}', N'PID data as defined in the controller: P={1}, I={2}, D={3}', N'["", "", ""]'),
    (N'רגשים', N'Report', 110, N'ערך נקודת הטל נמדד ובוצע חישוב עבור ערך לחות יחסית.', N'Relative humidity calculated from measured dew point.', NULL),
    (N'רגשים', N'Report', 120, N'המכשיר הגיע ונבדק עם אמיסביות {1}=ɛ.', N'Instrument received and tested with emissivity ɛ={1}.', N'["0.95"]'),
    (N'רגשים', N'Report', 130, N'המכשיר הגיע וכויל עם המקדמים הבאים: {1}', N'Instrument received and calibrated with the following coefficients: {1}', N'[""]'),
    (N'רגשים', N'Report', 140, N'חושבו מקדמים חדשים לפי ITS90.', N'New coefficients calculated according to ITS-90.', NULL),
    (N'רגשים', N'Report', 150, N'לצורך הבחנת תופעת חשל ברגש בוצעה בדיקה חוזרת לנקודת כיול {1} בירידה. החשל הנמדד הנו {2}.', N'To evaluate sensor hysteresis, calibration point {1} was retested during decreasing temperatures; the measured hysteresis is {2}.', N'["", ""]'),
    (N'רגשים', N'Report', 160, N'בדיקה בTPW נעשתה לפני ואחרי הכיול, התקבלה סטייה של {1}, התוצאה בטבלה היא לאחר כיול.', N'TPW test performed before and after calibration, deviation of {1} obtained, table result is post-calibration.', N'[""]'),
    (N'רגשים', N'Report', 170, N'GT={1}', N'GT={1}', N'[""]'),
    (N'רגשים', N'Report', 180, N'כיול בוצע במרחק {1} ס"מ מכייל אינפרא אדום.', N'Calibration performed at a distance of {1} cm from the infrared calibrator.', N'[""]'),
    (N'רגשים', N'Report', 190, N'נבדק בכוון אחד בלבד לפי סדר הופעת התוצאות בטבלה.', N'Tested in one direction only, following the order of results in the table.', NULL),
    (N'רגשים', N'Report', 200, N'טמפרטורות הבדיקה, מספר ומיקום נקודות הבדיקה - בתאום עם הלקוח.', N'Test temperatures, number, and location of test points coordinated with the customer.', NULL),
    (N'רגשים', N'Report', 210, N'בוצע כיוון.', N'Adjustment performed.', NULL),
    (N'רגשים', N'Report', 220, N'ראה תוצאות לפני ואחרי כיוון', N'See results before and after adjustment.', NULL),
    (N'רגשים', N'Report', 230, N'בוצע תיקון', N'Repair performed.', NULL),
    (N'רגשים', N'Report', 240, N'הוחלפו סוללות', N'Batteries replaced.', NULL),
    (N'רגשים', N'Report', 250, N'סוללה חלשה, נבדק באמצעות סוללות של מ.ב.א.', N'Low battery. Tested using a QCC batteries.', NULL),
    (N'משאיות קירור', N'Report', 10, N'הרכב מיועד להובלה בקירור.', N'The vehicle is designated for refrigerated transport.', NULL),
    (N'משאיות קירור', N'Report', 20, N'הרכב מיועד להובלה בהקפאה.', N'The vehicle is designated for frozen transport.', NULL),
    (N'משאיות קירור', N'Report', 30, N'הרכב מיועד להובלה בצינון.', N'The vehicle is designated for chilled transport.', NULL),
    (N'משאיות קירור', N'Report', 40, N'הרכב מיועד להובלה בקירור+הקפאה.', N'The vehicle is designated for dual refrigerated + frozen transport.', NULL),
    (N'משאיות קירור', N'Report', 50, N'לא קיים מד חום חוגה.', N'No dial thermometer exists.', NULL),
    (N'משאיות קירור', N'Report', 60, N'לא קיים רשם טמפרטורה.', N'No temperature recorder exists.', NULL),
    (N'משאיות קירור', N'Report', 70, N'לא קיים אוגר נתונים.', N'No data logger exists.', NULL),
    (N'משאיות קירור', N'Report', 80, N'מד חום חוגה אינו תקין.', N'Dial thermometer is faulty.', NULL),
    (N'משאיות קירור', N'Report', 90, N'רשם טמפרטורה אינו תקין.', N'Temperature recorder is faulty.', NULL),
    (N'משאיות קירור', N'Report', 100, N'אוגר נתונים אינו תקין.', N'Data logger is faulty.', NULL),
    (N'משאיות קירור', N'Report', 110, N'הכיול בוצע בנקודה אחת לפי יעוד ההובלה בהתאם לדרישות הלקוח.', N'The calibration was performed at a single point according to the transport designation and in line with customer requirements.', NULL);

DECLARE @Missing NVARCHAR(400) =
    (SELECT STRING_AGG(s.SecondaryCategoryName, N', ')
     FROM (SELECT DISTINCT SecondaryCategoryName FROM @Seed) AS s
     WHERE NOT EXISTS (SELECT 1 FROM dbo.SecondaryCategories AS c
                       WHERE c.SecondaryCategoryName = s.SecondaryCategoryName AND c.IsDeleted = 0));
IF @Missing IS NOT NULL
BEGIN
    DECLARE @Msg NVARCHAR(500) = CONCAT(N'Stopped, nothing changed: no live SecondaryCategories row named ', @Missing);
    THROW 51000, @Msg, 1;
END;

DECLARE @Plan TABLE
(
    Action                NVARCHAR(10),
    SecondaryCategoryId   INT,
    SecondaryCategoryName NVARCHAR(100),
    Scope                 NVARCHAR(10),
    DisplayOrder          INT,
    TextHEB               NVARCHAR(1000),
    TextENG               NVARCHAR(1000),
    DefaultValues         NVARCHAR(1000)
);

INSERT @Plan
SELECT Action = CASE WHEN p.PredefinedRemarkId IS NULL THEN N'Insert'
                     WHEN p.TextENG = s.TextENG COLLATE Latin1_General_100_BIN2
                      AND ISNULL(p.DefaultValues, N'') = ISNULL(s.DefaultValues, N'') COLLATE Latin1_General_100_BIN2
                      AND p.DisplayOrder = s.DisplayOrder
                     THEN N'Same' ELSE N'Differs' END,
       c.ID, s.SecondaryCategoryName, s.Scope, s.DisplayOrder, s.TextHEB, s.TextENG, s.DefaultValues
FROM @Seed AS s
JOIN dbo.SecondaryCategories AS c ON c.SecondaryCategoryName = s.SecondaryCategoryName AND c.IsDeleted = 0
OUTER APPLY (SELECT TOP (1) p.* FROM dbo.PredefinedRemarks AS p
             WHERE p.SecondaryCategoryId = c.ID AND p.Scope = s.Scope
               AND p.TextHEB = s.TextHEB COLLATE Latin1_General_100_BIN2
             ORDER BY p.IsActive DESC, p.PredefinedRemarkId DESC) AS p;

IF @Apply = 1
BEGIN
    BEGIN TRANSACTION;

    INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder)
    SELECT SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder
    FROM @Plan
    WHERE Action = N'Insert'
    ORDER BY SecondaryCategoryName, Scope, DisplayOrder;

    COMMIT TRANSACTION;
END;

SELECT Applied = @Apply, Action, SecondaryCategoryName, Scope, Remarks = COUNT(*)
FROM @Plan
GROUP BY Action, SecondaryCategoryName, Scope
ORDER BY Action, SecondaryCategoryName, Scope;
GO
