-- =============================================
-- Proc:        dbo.GetCustomerByCode
-- Description: Look up a customer by its customer code (HP number). Mirrors the Priority
--              lookup (amaba.dbo.CUSTOMERS: CUST/CUSTNAME/CUSTDES) against the synced
--              Calibrator table: CustomerIdFromSource = Priority CUST, CustomerCode = HP,
--              CustomerName = company name. Deployed identically to STAGE (Calibrator) and
--              PROD (CalibratorProd).
-- Param:       @CustomerCode NVARCHAR(50) — the customer code / HP number (e.g. '7700').
-- Returns:     0 or 1 active customer row.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerByCode]
    @CustomerCode NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         c.CustomerId
        ,c.CustomerIdFromSource AS id_internal      -- = Priority CUST
        ,c.CustomerCode         AS hp_number        -- = Priority CUSTNAME (HP)
        ,c.CustomerName         AS company_name     -- = Priority CUSTDES
        ,c.CustomerNameENG      AS company_name_eng
        ,c.CustomerCity
        ,c.CustomerPhone
        ,c.SourceId
    FROM dbo.Customers AS c
    WHERE c.CustomerCode = @CustomerCode
      AND ISNULL(c.IsDeleted, 0) = 0;
END
GO
