USE [XCIGroupAdmin]
GO
INSERT [Types].[Alert_SettingBits] ([AlertCode], [Name], [SendSMS], [SendEmail], [Visible], [IsActive], [Interval]) VALUES (1, N'Low Flow', 1, 1, 1, 1, 2)
GO
INSERT [Types].[Alert_SettingBits] ([AlertCode], [Name], [SendSMS], [SendEmail], [Visible], [IsActive], [Interval]) VALUES (2, N'High Flow', 1, 1, 1, 1, 2)
GO
INSERT [Types].[Alert_SettingBits] ([AlertCode], [Name], [SendSMS], [SendEmail], [Visible], [IsActive], [Interval]) VALUES (3, N'Low Current', 1, 1, 1, 1, 2)
GO
INSERT [Types].[Alert_SettingBits] ([AlertCode], [Name], [SendSMS], [SendEmail], [Visible], [IsActive], [Interval]) VALUES (4, N'High Current', 1, 1, 1, 1, 2)
GO
INSERT [Types].[Alert_SettingBits] ([AlertCode], [Name], [SendSMS], [SendEmail], [Visible], [IsActive], [Interval]) VALUES (5, N'No Flow', 1, 1, 1, 1, 2)
GO
INSERT [Types].[Alert_SettingBits] ([AlertCode], [Name], [SendSMS], [SendEmail], [Visible], [IsActive], [Interval]) VALUES (6, N'No Communication', 1, 1, 1, 1, 2)
GO
INSERT [Types].[ClockView] ([ViewID], [Name]) VALUES (1, N'AM_PM')
GO
INSERT [Types].[ClockView] ([ViewID], [Name]) VALUES (2, N'24Hours')
GO
--INSERT [Types].[CycleSoakPattern] ([PatternID], [Name]) VALUES (1, N'ww')
--GO


SET IDENTITY_INSERT [Types].[DeviceModel] ON 

GO
INSERT [Types].[DeviceModel] ([ModelID], [Name], [MaxZones]) VALUES (1, N'Model 16', 8, 0)
INSERT [Types].[DeviceModel] ([ModelID], [Name], [MaxZones]) VALUES (2, N'Model 8', 8, 1)

GO

SET IDENTITY_INSERT [Types].[DeviceModel] OFF
GO


INSERT [Types].[FlowSensor] ([UnitID], [Name]) VALUES (1, N'Pulse')
GO
INSERT [Types].[FlowSensor] ([UnitID], [Name]) VALUES (2, N'DI')
GO
INSERT [Types].[OperationSequence] ([SequenceTypeID], [Name]) VALUES (1, N'Parallel')
GO
INSERT [Types].[OperationSequence] ([SequenceTypeID], [Name]) VALUES (2, N'MasterFirst')
GO
INSERT [Types].[OperationSequence] ([SequenceTypeID], [Name]) VALUES (3, N'MasterLast')
GO
INSERT [Types].[RainSensor] ([TypeID], [Name]) VALUES (1, N'NC')
GO
INSERT [Types].[RainSensor] ([TypeID], [Name]) VALUES (2, N'NO')
GO
INSERT [Types].[ScheduleTypes] ([TypeID], [Name]) VALUES (1, N'Weekly')
GO
INSERT [Types].[ScheduleTypes] ([TypeID], [Name]) VALUES (2, N'Odd')
GO
INSERT [Types].[ScheduleTypes] ([TypeID], [Name]) VALUES (3, N'Even')
GO
INSERT [Types].[TempratureUnit] ([UnitID], [Name]) VALUES (1, N'Fahrenheit')
GO
INSERT [Types].[TempratureUnit] ([UnitID], [Name]) VALUES (2, N'Cellcius')
GO
