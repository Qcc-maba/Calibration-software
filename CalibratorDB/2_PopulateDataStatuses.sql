/*				
--------------------------------------------------------------------------------------
 Should be executed after [dbo].[StatusesCategories]
--------------------------------------------------------------------------------------
*/
SET IDENTITY_INSERT [dbo].[Statuses] ON 
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (1, 3, NULL, N'Available', N'תקין')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (2, 3, NULL, N'Treatment', N'בטיפול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (3, 3, NULL, N'Damaged', N'תקול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (8, 1, N'AA        ', NULL, N'נקלט')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (9, 1, N'AC        ', NULL, N'פתיחת כיול חדש')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (10, 4, NULL, N'Waitting for calibration', N'מחכה לכיול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (11, 4, NULL, N'In calibration', N'בכיול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (12, 4, NULL, N'Calibration failed', N'כיול נכשל')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (13, 4, NULL, N'Packaged', N'אריזה')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (14, 4, NULL, N'Calibration success', N'כיול הצליח')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (15, 4, NULL, N'Delivered', N'נשלח')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (16, 5, NULL, NULL, N'תקין')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (17, 5, NULL, NULL, N'אטם דלת פגום')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (18, 5, NULL, NULL, N'ידית שבורה')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (19, 5, NULL, NULL, N'דלת לא תקינה')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (20, 5, NULL, NULL, N'מאוור לא תקין')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (21, 5, NULL, NULL, N'סדק בזכוכית')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (22, 6, NULL, N'Packing', N'אריזה')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (23, 6, NULL, N'Customer complaint', N'תלונת לקוח')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (24, 6, NULL, N'Shared', N'משותף')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (25, 6, NULL, N'Urgent', N'דחוף ')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (26, 7, NULL, N'Available', N'תקין')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (27, 7, NULL, N'Treatment', N'טיפול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (28, 7, NULL, N'Damage', N'פגום')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (29, 7, NULL, N'In Calibration', N'בכיול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (30, 8, NULL, N'Available', N'זמין ')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (31, 8, NULL, N'Treatment', N'טיפול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (32, 8, NULL, N'Damage', N'תקול ')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (33, 9, NULL, N'Available', N'זמין ')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (34, 9, NULL, N'Sick', N'חולה')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (35, 9, NULL, N'Vacation', N'חופשה')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (36, 9, NULL, N'Maba', N'מ.ב.א')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (37, 9, NULL, N'InActive', N'לא פעיל')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (38, 10, NULL, N'Available', N'זמין ')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (39, 10, NULL, N'NotCalibrated', N'לא מכויל')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (40, 10, NULL, N'Damaged', N'תקול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (41, 10, NULL, N'Lost', N'אבד')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (42, 10, NULL, N'Sent for calibration', N'נשלח לכיול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (43, 11, NULL, N'Available', N'תקין')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (44, 11, NULL, N'Treatment', N'בטיפול')
GO
INSERT [dbo].[Statuses] ([StatusId], [StatusCategoryId], [Code], [StatusDescriptionENG], [StatusDescriptionHEB]) VALUES (45, 11, NULL, N'Damaged', N'תקול')
GO
SET IDENTITY_INSERT [dbo].[Statuses] OFF