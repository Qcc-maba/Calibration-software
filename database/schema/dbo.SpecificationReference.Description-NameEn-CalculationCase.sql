/*
    dbo.SpecificationReference: Description, NameEn, CalculationCase                     MBA-623
    ---------------------------------------------------------------------------------------------
    A reference document ("mesmach yichus") had only a Name, and the app used that name for three
    jobs at once: the label in the picker, the text on the report, and - by searching it for known
    substrings - the choice of calculation in the summary. Renaming "AMS 2750" to "AMS-2750" would
    have made the summary throw. These columns give each job its own field, so the name can be
    edited freely:

      Description      the explanation shown under the name in the picker (Excel column B)
      NameEn           the name printed on an English report (Excel column C); Name stays the
                       Hebrew one (column A)
      CalculationCase  1 = mean of averages, 2 = extreme values - what the summary computes.
                       NULL = no calculation defined; the summary reports that, as it did before
                       for a name it could not match.

    All nullable, so nothing changes for a row until Update-ChamberReferenceDocuments.sql fills it.
    Replayable.
*/
IF COL_LENGTH('dbo.SpecificationReference', 'Description') IS NULL
    ALTER TABLE dbo.SpecificationReference ADD Description NVARCHAR(200) NULL;
GO
IF COL_LENGTH('dbo.SpecificationReference', 'NameEn') IS NULL
    ALTER TABLE dbo.SpecificationReference ADD NameEn NVARCHAR(100) NULL;
GO
IF COL_LENGTH('dbo.SpecificationReference', 'CalculationCase') IS NULL
    ALTER TABLE dbo.SpecificationReference ADD CalculationCase TINYINT NULL
        CONSTRAINT CK_SpecificationReference_CalculationCase CHECK (CalculationCase IN (1, 2));
GO
