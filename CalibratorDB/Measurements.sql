
SET IDENTITY_INSERT [dbo].[Measurements] ON 
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (1, N'Temperature', N'טמפרטורה', NULL, NULL, 4, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (2, N'Pressure', N'לחץ', NULL, NULL, 4, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (3, N'Humidity', N'לחות', NULL, NULL, 4, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (4, N'CO2_Concentration', N'ריכוז CO2', NULL, NULL, 4, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (5, N'Pressure absolute', N'לחץ אבסולוטי', NULL, NULL, 4, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (6, N'Voltage_DC', N'מתח ישר', NULL, NULL, 1, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (7, N'Resistance', N'התנגדות', NULL, NULL, 1, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (8, N'Frequency', N'תדירות', NULL, NULL, 1, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (9, N'Voltage_AC', N'מתח חילופין', NULL, NULL, 4, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
INSERT [dbo].[Measurements] ([ID], [NameEn], [NameHe], [NoteEn], [NoteHe], [DepartmentId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID]) VALUES (10, N'RPM', N'מד מהירות', NULL, NULL, 4, CAST(N'2025-04-15T09:16:19.0000000' AS DateTime2), NULL, 0, NULL)
GO
SET IDENTITY_INSERT [dbo].[Measurements] OFF