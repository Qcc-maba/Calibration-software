CREATE TABLE [dbo].[Units] (
    [ID]             INT            IDENTITY (1, 1) NOT NULL,
    [ShortNameEn]    NVARCHAR (10)  NOT NULL,
    [ShortNameEnAsc] NVARCHAR (50)   NOT NULL,
    [LongNameEn]     NVARCHAR (100) NOT NULL,
    [ShortNameHeAsc] NVARCHAR (50)   NOT NULL,
    [ShortNameHe]    NVARCHAR (50)  NOT NULL,
    [LongNameHe]     NVARCHAR (100) NOT NULL,
    [GroupID]        INT            NOT NULL,
    [Note]           NVARCHAR (500) NULL,
    [CreatedDate]    DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]    DATETIME2 (0)  NULL,
    [IsDeleted]      BIT            DEFAULT ((0)) NOT NULL,
    [UpdateUserID]   INT            NULL,
    CONSTRAINT [PK_Units] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_MeasurementDevicesManufacturers_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_MeasurementDevicesSubClass_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_Units_UnitGroups] FOREIGN KEY ([GroupID]) REFERENCES [dbo].[UnitGroups] ([ID]),
    CONSTRAINT [FK_Units_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

