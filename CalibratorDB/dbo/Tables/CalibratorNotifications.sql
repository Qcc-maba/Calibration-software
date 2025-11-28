CREATE TABLE [dbo].[CalibratorNotifications] (
    [CalibratorId]             INT            NOT NULL,
    [CalibratorNotificationId] INT            IDENTITY (1, 1) NOT NULL,
    [OrderWorkPlanId]          INT            NULL,
    [OrderDetailId]            INT            NULL,
    [OrderDetailItemId]        INT            NULL,
    [NotificationText]         NVARCHAR (200) NULL,
    [NotificationTypeId]       INT            NULL,
    [ResolvedDate]             DATETIME2 (0)  NULL,
    [CreatedDate]              DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [CreateUserId]             INT            NOT NULL,
    [UpdatedDate]              DATETIME2 (0)  NULL,
    [UpdateUserID]             INT            NULL,
    [IsDeleted]                BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [FK_CalibratorNotifications_CalibratorId] FOREIGN KEY ([CalibratorId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorNotifications_CreateUserId] FOREIGN KEY ([CreateUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorNotifications_NotificationTypeId] FOREIGN KEY ([NotificationTypeId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_CalibratorNotifications_OrderWorkPlanId] FOREIGN KEY ([OrderWorkPlanId]) REFERENCES [dbo].[OrderWorkPlans] ([OrderWorkPlanId]),
    CONSTRAINT [FK_CalibratorNotifications_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);




GO
CREATE UNIQUE CLUSTERED INDEX [IDX_CalibratorNotifications_CalibratorId_CalibratorNotificationId]
    ON [dbo].[CalibratorNotifications]([CalibratorId] ASC, [CalibratorNotificationId] ASC);

