-- =============================================
-- Proc:        dbo.GetCatalogTextByPart
-- Jira:        MBA-806 ("Add description to the device")
-- Description: Returns the CRM catalog free-text (טקסט למק"ט) for a catalog number (PART),
--              from Priority amaba.dbo.PARTTEXT via the existing linked server [31.168.173.93].
--              The CRM stores the text as multi-line, CHARACTER-REVERSED HTML (RTL artifact);
--              reconstructed with STRING_AGG(REVERSE(TEXT)) ordered by TEXTLINE, TEXTORD.
-- Param:       @PART INT — the catalog number (= OrderDetails.PART / amaba PARTTEXT.PART).
-- Returns:     one row: PART, CatalogText (NULL when the part has no CRM text).
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCatalogTextByPart]
    @PART INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         @PART AS PART
        ,STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), pt.[TEXT])), N'')
             WITHIN GROUP (ORDER BY pt.[TEXTLINE], pt.[TEXTORD]) AS CatalogText
    FROM [31.168.173.93].[amaba].[dbo].[PARTTEXT] AS pt
    WHERE pt.[PART] = @PART;
END
GO
