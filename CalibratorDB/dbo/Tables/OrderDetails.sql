CREATE TABLE [dbo].[OrderDetails] (
    [OrderWorkPlanId]       INT             NOT NULL,
    [OrderDetailId]         INT             IDENTITY (1, 1) NOT NULL,
    [SpecialCareTypeId]     INT             NULL,
    [IsInHouse]             INT             NULL,
    [PartName]              NVARCHAR (22)   NULL,
    [KLINE]                 INT             NULL,
    [VPRICE]                DECIMAL (18, 2) NULL,
    [PRICE]                 DECIMAL (18, 2) NULL,
    [OrderLineCnt]          INT             NULL,
    [CreatedDate]           DATETIME2 (0)   CONSTRAINT [DF_OrderDetails_CreatedDate] DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]           DATETIME2 (0)   NULL,
    [CreatedByUserId]       INT             NULL,
    [UpdateUserID]          INT             NULL,
    [IsDeleted]             BIT             CONSTRAINT [DF_OrderDetails_IsDeleted] DEFAULT ((0)) NOT NULL,
    [IsCancelled]           BIT             CONSTRAINT [DF_OrderDetails_IsCancelled] DEFAULT ((0)) NOT NULL,
    [OrdersProductTypeId]   INT             NULL,
    [PART]                  INT             NULL,
    [ActualCalibrationDate] DATE            NULL,
    CONSTRAINT [PK_OrderDetails] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] ASC, [OrderDetailId] ASC),
    CONSTRAINT [FK_OrderDetails_OrdersProductTypeId] FOREIGN KEY ([OrdersProductTypeId]) REFERENCES [dbo].[OrdersProductTypes] ([OrdersProductTypeId]),
    CONSTRAINT [FK_OrderDetails_SpecialCareTypeId] FOREIGN KEY ([SpecialCareTypeId]) REFERENCES [dbo].[Statuses] ([StatusId])
);

