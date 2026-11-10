/*
    HOTFIX 2026-10-25, after release 25.Oct.2026 - PROD only.

    WHY
    ---
    The 31/08 production package created dbo.OrderNote, dbo.CustomerPortalRequest,
    dbo.CustomerPortalRequestItem and dbo.OrderApprovalRequest without the DEFAULT, CHECK, FOREIGN KEY
    and index definitions that STAGE has. Nobody wrote to them until today's release.
      - dbo.AddOrderNote does not pass CreatedDate / IsDeleted, so every validator note fails with
        "Cannot insert the value NULL" (seen in the smoke test, order 122).
      - dbo.CreateCustomerPortalRequest does not pass CreatedDate / IsDeleted either, so every portal
        action popup (MBA-903) fails the same way.
    All four tables had 0 rows on PROD when this was written, so every statement below is instant and
    cannot be rejected by existing data. Names and definitions are copied from STAGE.

    Safe to re-run: every object is created only if it does not exist yet.
    All-or-nothing: one transaction, XACT_ABORT ON.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- required for the filtered indexes
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT ON;
GO


/* PROD-only: refuse to run anywhere else. STAGE (Calibrator) and PROD (CalibratorProd) share one
   server, so an SSMS tab can be on either; on STAGE every guard below is already met, the script
   changes nothing and still prints its check row - which looks exactly like success. */
IF DB_NAME() <> N'CalibratorProd'
BEGIN
    /* RAISERROR, not THROW: SSMS goes on to the next batch after an error, so the rest of the file is
       switched off with NOEXEC. Run SET NOEXEC OFF; afterwards, or open a new tab, before anything else. */
    DECLARE @WrongDb NVARCHAR(200) = CONCAT(N'Stopped, nothing changed: this script is for CalibratorProd, but the current database is ', DB_NAME(), N'. Run SET NOEXEC OFF; before anything else in this tab.');
    RAISERROR(@WrongDb, 16, 1);
    SET NOEXEC ON;
END;
GO

BEGIN TRANSACTION;

/* ---- dbo.OrderNote (MBA-907) ---------------------------------------------------------------- */
IF OBJECT_ID('dbo.DF_OrderNote_CreatedDate', 'D') IS NULL
    ALTER TABLE dbo.OrderNote ADD CONSTRAINT DF_OrderNote_CreatedDate DEFAULT (sysutcdatetime()) FOR CreatedDate;
IF OBJECT_ID('dbo.DF_OrderNote_IsDeleted', 'D') IS NULL
    ALTER TABLE dbo.OrderNote ADD CONSTRAINT DF_OrderNote_IsDeleted DEFAULT ((0)) FOR IsDeleted;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrderNote_Order_Created' AND object_id = OBJECT_ID('dbo.OrderNote'))
    CREATE NONCLUSTERED INDEX IX_OrderNote_Order_Created
        ON dbo.OrderNote (OrderWorkPlanId, CreatedDate DESC)
        INCLUDE (NoteText, CreatedByEmail)
        WHERE IsDeleted = 0;

/* ---- dbo.CustomerPortalRequest / Item (MBA-903) --------------------------------------------- */
IF OBJECT_ID('dbo.DF_CustomerPortalRequest_Status', 'D') IS NULL
    ALTER TABLE dbo.CustomerPortalRequest ADD CONSTRAINT DF_CustomerPortalRequest_Status DEFAULT (N'New') FOR Status;
IF OBJECT_ID('dbo.DF_CustomerPortalRequest_CreatedDate', 'D') IS NULL
    ALTER TABLE dbo.CustomerPortalRequest ADD CONSTRAINT DF_CustomerPortalRequest_CreatedDate DEFAULT (sysutcdatetime()) FOR CreatedDate;
IF OBJECT_ID('dbo.DF_CustomerPortalRequest_IsDeleted', 'D') IS NULL
    ALTER TABLE dbo.CustomerPortalRequest ADD CONSTRAINT DF_CustomerPortalRequest_IsDeleted DEFAULT ((0)) FOR IsDeleted;
IF OBJECT_ID('dbo.CK_CustomerPortalRequest_Status', 'C') IS NULL
    ALTER TABLE dbo.CustomerPortalRequest WITH CHECK ADD CONSTRAINT CK_CustomerPortalRequest_Status
        CHECK ([Status]=N'Done' OR [Status]=N'Cancelled' OR [Status]=N'Rejected' OR [Status]=N'Approved' OR [Status]=N'InProgress' OR [Status]=N'New');
IF OBJECT_ID('dbo.CK_CustomerPortalRequest_Type', 'C') IS NULL
    ALTER TABLE dbo.CustomerPortalRequest WITH CHECK ADD CONSTRAINT CK_CustomerPortalRequest_Type
        CHECK ([RequestType]=N'DeviceRemoval' OR [RequestType]=N'QuoteFeedback' OR [RequestType]=N'Quote' OR [RequestType]=N'CalibrationCancellation' OR [RequestType]=N'CalibrationExtension' OR [RequestType]=N'Shipment' OR [RequestType]=N'ReportUpdate');
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CustomerPortalRequest_Customer_Created' AND object_id = OBJECT_ID('dbo.CustomerPortalRequest'))
    CREATE NONCLUSTERED INDEX IX_CustomerPortalRequest_Customer_Created
        ON dbo.CustomerPortalRequest (CustomerId, CreatedDate DESC)
        INCLUDE (RequestType, Status, OrderWorkPlanId, MbaReportNumber, QuoteNumber);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CustomerPortalRequest_Status_Created' AND object_id = OBJECT_ID('dbo.CustomerPortalRequest'))
    CREATE NONCLUSTERED INDEX IX_CustomerPortalRequest_Status_Created
        ON dbo.CustomerPortalRequest (Status, CreatedDate DESC)
        WHERE IsDeleted = 0;
IF OBJECT_ID('dbo.FK_CustomerPortalRequestItem_Request', 'F') IS NULL
    ALTER TABLE dbo.CustomerPortalRequestItem WITH CHECK ADD CONSTRAINT FK_CustomerPortalRequestItem_Request
        FOREIGN KEY (CustomerPortalRequestId) REFERENCES dbo.CustomerPortalRequest (CustomerPortalRequestId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CustomerPortalRequestItem_Request' AND object_id = OBJECT_ID('dbo.CustomerPortalRequestItem'))
    CREATE NONCLUSTERED INDEX IX_CustomerPortalRequestItem_Request
        ON dbo.CustomerPortalRequestItem (CustomerPortalRequestId);

/* ---- dbo.OrderApprovalRequest (MBA-888): inserts already work, but the token must be unique ---- */
IF OBJECT_ID('dbo.CK_OrderApprovalRequest_Decision', 'C') IS NULL
    ALTER TABLE dbo.OrderApprovalRequest WITH CHECK ADD CONSTRAINT CK_OrderApprovalRequest_Decision
        CHECK ([Decision] IS NULL OR ([Decision]=N'Rejected' OR [Decision]=N'Confirmed'));
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_OrderApprovalRequest_TokenHash' AND object_id = OBJECT_ID('dbo.OrderApprovalRequest'))
    CREATE UNIQUE NONCLUSTERED INDEX UX_OrderApprovalRequest_TokenHash
        ON dbo.OrderApprovalRequest (TokenHash);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrderApprovalRequest_Order_CreatedAt' AND object_id = OBJECT_ID('dbo.OrderApprovalRequest'))
    CREATE NONCLUSTERED INDEX IX_OrderApprovalRequest_Order_CreatedAt
        ON dbo.OrderApprovalRequest (OrderWorkPlanId, CreatedAt DESC)
        INCLUDE (ExpiresAt, RespondedAt, InvalidatedAt, Decision, SentToEmail);

COMMIT TRANSACTION;
GO

/* ---- Check: expect a single row reading 5 | 3 | 6 | 1 ------------------------------------- */
SELECT
    (SELECT COUNT(*) FROM sys.default_constraints WHERE name IN
        ('DF_OrderNote_CreatedDate','DF_OrderNote_IsDeleted','DF_CustomerPortalRequest_Status',
         'DF_CustomerPortalRequest_CreatedDate','DF_CustomerPortalRequest_IsDeleted'))          AS defaults_expect_5,
    (SELECT COUNT(*) FROM sys.check_constraints WHERE name IN
        ('CK_CustomerPortalRequest_Status','CK_CustomerPortalRequest_Type','CK_OrderApprovalRequest_Decision')) AS checks_expect_3,
    (SELECT COUNT(*) FROM sys.indexes WHERE name IN
        ('IX_OrderNote_Order_Created','IX_CustomerPortalRequest_Customer_Created','IX_CustomerPortalRequest_Status_Created',
         'IX_CustomerPortalRequestItem_Request','UX_OrderApprovalRequest_TokenHash','IX_OrderApprovalRequest_Order_CreatedAt')) AS indexes_expect_6,
    (SELECT COUNT(*) FROM sys.foreign_keys WHERE name = 'FK_CustomerPortalRequestItem_Request') AS fk_expect_1;
GO
SET NOEXEC OFF;  -- harmless when the guard did not fire
GO
