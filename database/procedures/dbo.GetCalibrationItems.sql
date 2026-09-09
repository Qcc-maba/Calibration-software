/*
    dbo.GetCalibrationItems                                                            MBA-666
    ---------------------------------------------------------------------------------------------
    The list a calibrator picks the "פריט כיול" from, taken from Priority's DEVICE description.

    Which column, and why the first attempt was wrong
    -------------------------------------------------
    MBA-666 asks for "תיאור מכשיר". An earlier version of this procedure read OrdersProductType,
    which is "תיאור מוצר" - the sales line, one value per catalogue item. Catalogue item 110102 has
    a single product description, "תנור עד 550C", and several device descriptions beneath it:
    "תנור שריפה", "תנור לטיפול תרמי". The calibrator needs the latter.

    The device description is amaba.dbo.MBA_DOCLOAD.SERNDES, cached here in
    dbo.CrmDeviceDescription. 3,000 distinct values over 3.8M device records.

    No stripping is needed any more. בהסמכה / באתרכם / ק.משנה and the rest of the commercial tail
    belong to the product line, not the device - none of them appear in SERNDES. The nine-marker
    cut this procedure used to perform is gone.

    NeedsReview - read this before putting a value on a certificate
    ---------------------------------------------------------------
    Priority stores this text in visual order: the Hebrew reads correctly but each run of digits
    or Latin is reversed. "זחון אלקטרוני עד 051" is a 150 mm caliper. Description holds the
    un-reversed value; DescriptionRaw holds Priority's, so nothing is lost.

    Reversing a single number is exact. Two things are not, and those rows carry NeedsReview = 1:

      Latin letters   case cannot be recovered. "MN 622-0" un-reverses to "NM 0-226"; the
                      instrument is 0-226 Nm.
      several runs    their order is ambiguous. "מדיד חלק טבעת 05-1.5" could be several things.

    1,611 of the 3,000 are clean - Hebrew only, or a single number - and are safe as they stand.
    1,389 want a human eye. Pass @ReviewedOnly = 1 to see only the safe ones.
*/
CREATE OR ALTER PROCEDURE dbo.GetCalibrationItems
    @Search       NVARCHAR(200) = NULL,
    @MinDevices   INT           = 1,   /* raise to hide descriptions almost nothing uses */
    @ReviewedOnly BIT           = 0    /* 1 = only rows safe to print as-is */
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CalibrationItem = d.Description,
           PriorityRaw     = d.DescriptionRaw,
           d.NeedsReview,
           d.Devices,
           CatalogueItems  = d.Parts
    FROM dbo.CrmDeviceDescription AS d
    WHERE d.Devices >= ISNULL(@MinDevices, 1)
      AND (@ReviewedOnly = 0 OR d.NeedsReview = 0)
      AND (@Search IS NULL
           OR d.Description    LIKE N'%' + @Search + N'%'
           OR d.DescriptionRaw LIKE N'%' + @Search + N'%')
    ORDER BY d.Devices DESC, d.Description;
END
