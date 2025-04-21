CREATE TABLE [dbo].[CalibratorsAvailability] (
    [UserId]               INT           NOT NULL,
    [AvailabilityStatusId] INT           NOT NULL,
    [AvailbilityDateFrom]  DATE          NOT NULL,
    [AvailbilityDateTo]    DATE          NOT NULL,
    [CreatedDate]          DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]          DATETIME2 (0) NULL,
    [IsDeleted]            BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]         INT           NULL,
    CONSTRAINT [PK_Calibrators] PRIMARY KEY CLUSTERED ([UserId] ASC, [AvailbilityDateFrom] ASC),
    CONSTRAINT [FK_CalibratorsAvailability_AvailabilityStatusId] FOREIGN KEY ([AvailabilityStatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_CalibratorsAvailability_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorsAvailability_UserId] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID])
);

