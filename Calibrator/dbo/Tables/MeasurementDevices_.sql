CREATE TABLE [dbo].[MeasurementDevices_] (
    [ID]                  INT           IDENTITY (1, 1) NOT NULL,
    [MabaID]              VARCHAR (20)  NOT NULL,
    [Active]              BIT           CONSTRAINT [DF_MeasurementDevices_Active] DEFAULT ((1)) NOT NULL,
    [CalibrationDate]     DATETIME      NULL,
    [NextCalibrationDate] DATETIME      NULL,
    [DepartmentId]        INT           NOT NULL,
    [EquipmentStatusId]   INT           NULL,
    [Owner]               INT           NULL,
    [WorkRangeMin]        REAL          NULL,
    [WorkRangeMax]        REAL          NULL,
    [WorkRangeUnit]       INT           NULL,
    [ReferenceEquipment]  VARCHAR (50)  NULL,
    [Description]         VARCHAR (50)  NULL,
    [CreateDate]          DATETIME2 (7) CONSTRAINT [DF_MeasurementDevices_CreateDate] DEFAULT (getdate()) NULL,
    [UpdateUserID]        INT           NULL,
    [DeviceFunctionId]    INT           NULL
);

