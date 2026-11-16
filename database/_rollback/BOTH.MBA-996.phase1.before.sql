/*
    Rollback of MBA-996 phase 1 - the device entity                                      MBA-996
    ---------------------------------------------------------------------------------------------
    Puts the database back as it was before phase 1, on STAGE or PROD:
      - drops dbo.vwCustomerDevices, dbo.RefreshCustomerDevicesFromPriority,
        dbo.trCustomerDevices_PriorityOwned, dbo.fnSerialAlnum and IX_OrderDetailsItems_SERN;
      - re-creates dbo.CustomerDevices in its original shape, empty: PK (CustomerId,
        CustomerDeviceID), 8 foreign keys, 4 defaults - as captured from STAGE on 2026-11-10.
    The two SQL Agent jobs are removed separately (they live in msdb):
        EXEC msdb.dbo.sp_delete_job @job_name = N'MABA - Refresh customer devices';
        EXEC msdb.dbo.sp_delete_job @job_name = N'MABA - Refresh customer devices (full)';

    The rows the refresh loaded are copies of Priority and come back with the next refresh, so
    dropping them loses nothing. A device a CUSTOMER typed in (SERN IS NULL) exists nowhere else:
    if there is one, this file refuses and stops.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.CustomerDevices', 'SERN') IS NOT NULL
   AND EXISTS (SELECT 1 FROM dbo.CustomerDevices WHERE SERN IS NULL)
    THROW 51000, 'dbo.CustomerDevices holds devices typed in by customers (SERN IS NULL). They exist nowhere else: export them before rolling back.', 1;
GO

DROP VIEW      IF EXISTS dbo.vwCustomerDevices;
DROP PROCEDURE IF EXISTS dbo.RefreshCustomerDevicesFromPriority;
DROP TRIGGER   IF EXISTS dbo.trCustomerDevices_PriorityOwned;
DROP FUNCTION  IF EXISTS dbo.fnSerialAlnum;
DROP INDEX     IF EXISTS IX_OrderDetailsItems_SERN ON dbo.OrderDetailsItems;
GO

IF COL_LENGTH('dbo.CustomerDevices', 'SERN') IS NOT NULL
    DROP TABLE dbo.CustomerDevices;
GO

IF OBJECT_ID('dbo.CustomerDevices', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CustomerDevices
    (
        CustomerId                  INT            NOT NULL,
        CustomerDeviceID            INT IDENTITY(1,1) NOT NULL,
        MainCategoryId              INT            NULL,
        SecondaryCategoryId         INT            NULL,
        CustomerSiteId              INT            NULL,
        CustomerContactId           INT            NULL,
        OrdersProductTypeId         INT            NULL,
        Accuracy                    TINYINT        NULL,
        OrdersDeviceManufacturer    NVARCHAR(100)  NULL,
        DeviceLocation              NVARCHAR(50)   NULL,
        LastAdjustmentDate          DATETIME2(0)   NULL,
        Model                       NVARCHAR(150)  NULL,
        SerialNumber                NVARCHAR(50)   NULL,
        ManufacturerNumber          NVARCHAR(100)  NULL,
        AdditionalDeviceNumber      NVARCHAR(100)  NULL,
        DateFormatStructure         NVARCHAR(20)   NULL,
        NextCalibrationDate         DATETIME2(0)   NULL,
        CalibrationIntervalMonths   TINYINT        NULL,
        ReportLanguage              NVARCHAR(50)   NULL,
        IsThirdPartyCalibration     BIT            NULL CONSTRAINT DF_CustomerDevices_IsThirdPartyCalibration DEFAULT ((0)),
        BatteriesReplacement        BIT            NULL CONSTRAINT DF_CustomerDevices_BatteriesReplacement    DEFAULT ((0)),
        CalibrationMethod           NVARCHAR(100)  NULL,
        SpecificationReferenceId    INT            NULL,
        MeasurementsSpecificationId INT            NULL,
        PrimaryMeasurmentUnitId     INT            NULL,
        SecondaryMeasurmentUnitId   INT            NULL,
        CreatedDate                 DATETIME2(0)   NOT NULL CONSTRAINT DF_CustomerDevices_CreatedDate DEFAULT (getdate()),
        UpdatedDate                 DATETIME2(0)   NULL,
        UpdateUserID                INT            NULL,
        IsDeleted                   BIT            NOT NULL CONSTRAINT DF_CustomerDevices_IsDeleted DEFAULT ((0)),
        GuardBand                   DECIMAL(9,4)   NULL,
        CONSTRAINT PK_CustomerDevices PRIMARY KEY CLUSTERED (CustomerId, CustomerDeviceID),
        CONSTRAINT FK_CustomerDevices_CustomerId                  FOREIGN KEY (CustomerId)                  REFERENCES dbo.Customers (CustomerId),
        CONSTRAINT FK_CustomerDevices_MainCategoryId              FOREIGN KEY (MainCategoryId)              REFERENCES dbo.MainCategories (ID),
        CONSTRAINT FK_CustomerDevices_SecondaryCategoryId         FOREIGN KEY (SecondaryCategoryId)         REFERENCES dbo.SecondaryCategories (ID),
        CONSTRAINT FK_CustomerDevices_OrdersProductTypeId         FOREIGN KEY (OrdersProductTypeId)         REFERENCES dbo.OrdersProductTypes (OrdersProductTypeId),
        CONSTRAINT FK_CustomerDevices_SpecificationReferenceId    FOREIGN KEY (SpecificationReferenceId)    REFERENCES dbo.SpecificationReference (ID),
        CONSTRAINT FK_CustomerDevices_MeasurementsSpecificationId FOREIGN KEY (MeasurementsSpecificationId) REFERENCES dbo.MeasurementsSpecifications (ID),
        CONSTRAINT FK_CustomerDevices_PrimaryMeasurmentUnitId     FOREIGN KEY (PrimaryMeasurmentUnitId)     REFERENCES dbo.MeasurementDeviceUnits (MeasurementDeviceUnitId),
        CONSTRAINT FK_CustomerDevices_SecondaryMeasurmentUnitId   FOREIGN KEY (SecondaryMeasurmentUnitId)   REFERENCES dbo.MeasurementDeviceUnits (MeasurementDeviceUnitId)
    );
    PRINT 'dbo.CustomerDevices: original shape restored (empty).';
END
GO
