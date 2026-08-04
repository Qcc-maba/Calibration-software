-- =============================================
-- Proc:        dbo.GetCatalogTextByPart
-- Jira:        MBA-806 ("Add description to the device")
-- Description: Returns the CRM catalog free-text (טקסט למק"ט) for a catalog number (PART).
--              Reads from the LOCAL cache dbo.CrmCatalogText (fast); falls back to a live
--              linked-server read [31.168.173.93] for parts not yet cached. Cache is refreshed
--              by dbo.RefreshCrmTextCache (scheduled). CRM text is multi-line char-reversed HTML,
--              reconstructed with STRING_AGG(REVERSE(TEXT)) ORDER BY TEXTLINE,TEXTORD.
-- Param:       @PART INT (= OrderDetails.PART / amaba PARTTEXT.PART)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCatalogTextByPart]
    @PART INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         @PART AS PART
        ,COALESCE(
            (SELECT c.CatalogText FROM dbo.CrmCatalogText AS c WHERE c.PART = @PART),
            (SELECT STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), pt.[TEXT]) COLLATE DATABASE_DEFAULT), N'')
                    WITHIN GROUP (ORDER BY pt.[TEXTLINE], pt.[TEXTORD])
             FROM [31.168.173.93].[amaba].[dbo].[PARTTEXT] AS pt
             WHERE pt.[PART] = @PART)
         ) AS CatalogText;
END
GO
