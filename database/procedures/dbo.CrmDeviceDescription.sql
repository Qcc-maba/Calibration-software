/*
    dbo.CrmDeviceDescription                                                           MBA-666
    ---------------------------------------------------------------------------------------------
    The calibration item list, cached from Priority's device description
    (amaba.dbo.MBA_DOCLOAD.SERNDES - "תאור מכשיר" on the Priority form). 3,000 distinct values
    over 3.8M device records. Filled by dbo.RefreshDeviceDescriptions.

    This is deliberately NOT the product description. Catalogue item 110102 has one product
    description, "תנור עד 550C", and several devices beneath it - "תנור שריפה", "תנור לטיפול
    תרמי". A calibrator picks the device.

    Two text columns because Priority stores this in visual order and the un-reversal is not
    always exact. DescriptionRaw is Priority's own text, kept so nothing is lost. Description has
    its digit and Latin runs un-reversed. NeedsReview marks the rows a person still has to check.
*/
IF OBJECT_ID('dbo.CrmDeviceDescription') IS NULL
CREATE TABLE dbo.CrmDeviceDescription
(
    CrmDeviceDescriptionId INT IDENTITY(1,1) PRIMARY KEY,
    DescriptionRaw  NVARCHAR(200) NOT NULL,   -- exactly as Priority stores it (visual order)
    Description     NVARCHAR(200) NOT NULL,   -- digit and Latin runs un-reversed
    NeedsReview     BIT           NOT NULL,   -- Latin case lost, or run order ambiguous
    Devices         INT           NOT NULL,
    Parts           INT           NOT NULL,
    RefreshedAt     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
/* NOT unique: our collation is CI_AI and folds values Priority keeps apart. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CrmDeviceDescription_Raw')
    CREATE INDEX IX_CrmDeviceDescription_Raw ON dbo.CrmDeviceDescription(DescriptionRaw);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CrmDeviceDescription_Desc')
    CREATE INDEX IX_CrmDeviceDescription_Desc ON dbo.CrmDeviceDescription(Description);
GO
