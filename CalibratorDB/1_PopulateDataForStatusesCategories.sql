/*				
--------------------------------------------------------------------------------------
 Should be executed before	[dbo].[Statuses]		
--------------------------------------------------------------------------------------
*/
SET IDENTITY_INSERT [dbo].[StatusesCategories] ON 
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (1, N'ReportStatus', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (3, N'EquipmentStatus', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (4, N'CalibratedUnitsWorkStatus', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (5, N'CalibratedUnitsStatus', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (6, N'SpecialCare', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (7, N'CarStatus', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (8, N'CalibrationEquipmentStatus', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (9, N'CalibratorsAvailabilityStatus', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (10, N'MeasurementDeviceStatus			', NULL)
GO
INSERT [dbo].[StatusesCategories] ([StatusCategoryId], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (11, N'EquipmentStatus', NULL)
GO
SET IDENTITY_INSERT [dbo].[StatusesCategories] OFF