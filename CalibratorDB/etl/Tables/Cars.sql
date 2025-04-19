CREATE TABLE [etl].[Cars] (
    [CarId]                INT           NOT NULL,
    [MabaNumber]           INT           NULL,
    [Model]                NVARCHAR (50) NOT NULL,
    [LicenseNumber]        NVARCHAR (50) NOT NULL,
    [Seats]                TINYINT       NOT NULL,
    [TreatmentPeriod]      INT           NOT NULL,
    [NextTreatmentDate]    DATE          NOT NULL,
    [NextYearlyTestDate]   DATE          NOT NULL,
    [OwnerId]              INT           NULL,
    [CarStatusId]          INT           NOT NULL,
    [CreateDate]           DATETIME2 (0) NOT NULL,
    [UpdatedDate]          DATETIME2 (0) NULL,
    [AssignedCalibratorId] INT           NULL,
    [UpdateUserID]         INT           NULL,
    [IsDeleted]            BIT           NOT NULL
);

