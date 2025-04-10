CREATE TABLE [dbo].[CalibratorsCertifications] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [Certificate]  NVARCHAR (25) NOT NULL,
    [CreatedDate]  DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0) NULL,
    [IsDeleted]    BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID] INT           NULL,
    CONSTRAINT [PK_CalibratorsCertifications] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_CalibratorsCertifications_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

