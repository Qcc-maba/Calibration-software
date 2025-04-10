CREATE TABLE [dbo].[Cars] (
    [CarId]                INT           IDENTITY (1, 1) NOT NULL,
    [MabaNumber]           INT           NULL,
    [Model]                NVARCHAR (50) NOT NULL,
    [LicenseNumber]        NVARCHAR (50) NOT NULL,
    [Seats]                TINYINT       NOT NULL,
    [TreatmentPeriod]      INT           NOT NULL,
    [NextTreatmentDate]    DATE          NOT NULL,
    [NextYearlyTestDate]   DATE          NOT NULL,
    [OwnerId]              INT           NULL,
    [CarStatusId]          INT           NOT NULL,
    [CreateDate]           DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]          DATETIME2 (0) NULL,
    [AssignedCalibratorId] INT           NULL,
    [UpdateUserID]         INT           NULL,
    [IsDeleted]            BIT           DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([CarId] ASC),
    CONSTRAINT [FK_Cars_AssignedCalibratorId] FOREIGN KEY ([AssignedCalibratorId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_Cars_CarStatusId] FOREIGN KEY ([CarStatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_Cars_OwnerId] FOREIGN KEY ([OwnerId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_Cars_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

