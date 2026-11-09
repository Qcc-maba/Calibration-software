/*
    dbo.PriorityCalibrationStatusCodes                                                 MBA-911
    ---------------------------------------------------------------------------------------------
    The vocabulary of Priority's calibration status log: one row per code in
    amaba.dbo.MBA_CALIBSTATUSES (22 codes, e.g. AA "received", GR "report generated",
    H2 "second signature", TX "sent to customer"), plus what each code means in this system.

    Why a table of our own rather than reading MBA_CALIBSTATUSES every time:

    * Priority knows the code and its Hebrew text. It does not know WHO writes the code
      (Priority itself, or the calibration software), which stage of the lab flow it belongs to,
      or how it relates to our dbo.Statuses. Those columns are ours.
    * dbo.Statuses ids differ between STAGE and PROD (WaitingForCalibration is 76 on STAGE and 75
      on PROD). OrderStatusName therefore holds the status NAME (dbo.Statuses.StatusDescriptionENG
      in category OrderStatus) and is resolved at read time, never an id.

    Filled in two halves:
      - database/data/Seed-PriorityCalibrationStatusCodes.sql writes the English columns.
      - dbo.RefreshPriorityCalibrationStatus refreshes DescriptionHEB and PriorityStatusId from
        Priority on every run, and adds any code Priority has that the seed does not (marked
        Stage = 'Unknown' so it is visible, never silently dropped).

    Measured on Priority 2026-10-07 (30 days of MBA_CALIBSTATSLOG):
      written by Priority itself: AA 6,434 · TX 5,359 · KM 102 · PI 65 · CO 64
      written by the calibration software (MABA 2000, through MBA_CALIBLOAD): every other code.
    FX is sent by MABA 2000 but is NOT in MBA_CALIBSTATUSES, so Priority rejects it and it never
    reaches the log. It has no row here on purpose.
*/
IF OBJECT_ID('dbo.PriorityCalibrationStatusCodes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PriorityCalibrationStatusCodes
    (
        StatusCode        CHAR(2)        NOT NULL,  /* MBA_CALIBSTATUSES.STATCODE                       */
        PriorityStatusId  INT            NULL,      /* MBA_CALIBSTATUSES.CALIBSTATUSES (Priority's key)  */
        DescriptionHEB    NVARCHAR(100)  NULL,      /* STATDES, via system.dbo.tabula_hebconvert         */
        DescriptionENG    NVARCHAR(100)  NOT NULL,
        WrittenBy         VARCHAR(20)    NOT NULL,  /* 'Priority' | 'CalibrationSoftware' | 'Unknown'    */
        Stage             VARCHAR(20)    NOT NULL,  /* Intake, Calibration, OnHold, Report, Signature,
                                                       UpdateReport, Shipping, Subcontractor, Unknown    */
        SortOrder         TINYINT        NOT NULL,  /* typical position in the lab flow, for display.
                                                       NOT a rule: real Docs repeat and skip steps       */
        OrderStatusName   NVARCHAR(100)  NULL,      /* dbo.Statuses name (category OrderStatus), or NULL */
        UpdatedAt         DATETIME2(3)   NOT NULL
            CONSTRAINT DF_PriorityCalibrationStatusCodes_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_PriorityCalibrationStatusCodes PRIMARY KEY CLUSTERED (StatusCode),
        CONSTRAINT CK_PriorityCalibrationStatusCodes_WrittenBy
            CHECK (WrittenBy IN ('Priority', 'CalibrationSoftware', 'Unknown'))
    );
END
GO
