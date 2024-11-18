-- MF Database
-- Filling types script
------------------------------------------------------------------
USE [MFSystemAdmin]
GO

--[GlobalizationZone]
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (103, N'Dateline Standard Time', N'International Date Line West', N'Dateline Daylight Time', N'Dateline Standard Time', -720, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (104, N'UTC-11', N'Coordinated Universal Time-11', N'UTC-11', N'UTC-11', -660, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (105, N'Hawaiian Standard Time', N'Hawaii', N'Hawaiian Daylight Time', N'Hawaiian Standard Time', -600, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (106, N'Alaskan Standard Time', N'Alaska', N'Alaskan Daylight Time', N'Alaskan Standard Time', -540, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (107, N'Pacific Standard Time (Mexico)', N'Baja California', N'Pacific Daylight Time (Mexico)', N'Pacific Standard Time (Mexico)', -480, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (108, N'Pacific Standard Time', N'Pacific Time (US & Canada)', N'Pacific Daylight Time', N'Pacific Standard Time', -480, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (109, N'US Mountain Standard Time', N'Arizona', N'US Mountain Daylight Time', N'US Mountain Standard Time', -420, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (110, N'Mountain Standard Time (Mexico)', N'Chihuahua- La Paz- Mazatlan - New', N'Mountain Daylight Time (Mexico)', N'Mountain Standard Time (Mexico)', -420, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (111, N'Mountain Standard Time', N'Mountain Time (US & Canada)', N'Mountain Daylight Time', N'Mountain Standard Time', -420, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (112, N'Central America Standard Time', N'Central America', N'Central America Daylight Time', N'Central America Standard Time', -360, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (113, N'Central Standard Time', N'Central Time (US & Canada)', N'Central Daylight Time', N'Central Standard Time', -360, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (114, N'Central Standard Time (Mexico)', N'Guadalajara- Mexico City- Monterrey-New', N'Central Daylight Time (Mexico)', N'Central Standard Time (Mexico)', -360, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (115, N'Canada Central Standard Time', N'Saskatchewan', N'Canada Central Daylight Time', N'Canada Central Standard Time', -360, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (116, N'SA Pacific Standard Time', N'Bogota- Lima- Quito', N'SA Pacific Daylight Time', N'SA Pacific Standard Time', -300, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (117, N'Eastern Standard Time', N'Eastern Time (US & Canada)', N'Eastern Daylight Time', N'Eastern Standard Time', -300, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (118, N'US Eastern Standard Time', N'Indiana (East)', N'US Eastern Daylight Time', N'US Eastern Standard Time', -300, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (119, N'Venezuela Standard Time', N'Caracas', N'Venezuela Daylight Time', N'Venezuela Standard Time', -240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (120, N'Paraguay Standard Time', N'Asuncion', N'Paraguay Daylight Time', N'Paraguay Standard Time', -240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (121, N'Atlantic Standard Time', N'Atlantic Time (Canada)', N'Atlantic Daylight Time', N'Atlantic Standard Time', -240, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (122, N'Central Brazilian Standard Time', N'Cuiaba', N'Central Brazilian Daylight Time', N'Central Brazilian Standard Time', -240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (123, N'SA Western Standard Time', N'Georgetown- La Paz- Manaus- San Juan', N'SA Western Daylight Time', N'SA Western Standard Time', -240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (124, N'Pacific SA Standard Time', N'Santiago', N'Pacific SA Daylight Time', N'Pacific SA Standard Time', -240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (125, N'Newfoundland Standard Time', N'Newfoundland', N'Newfoundland Daylight Time', N'Newfoundland Standard Time', -210, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (126, N'E. South America Standard Time', N'Brasilia', N'E. South America Daylight Time', N'E. South America Standard Time', -180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (127, N'Argentina Standard Time', N'Buenos Aires', N'Argentina Daylight Time', N'Argentina Standard Time', -180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (128, N'SA Eastern Standard Time', N'Georgetown- La Paz- Manaus- San Juan', N'SA Eastern Daylight Time', N'SA Eastern Standard Time', -180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (129, N'Greenland Standard Time', N'Greenland', N'Greenland Daylight Time', N'Greenland Standard Time', -180, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (130, N'Montevideo Standard Time', N'Montevideo', N'Montevideo Daylight Time', N'Montevideo Standard Time', -180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (131, N'Bahia Standard Time', N'Salvador', N'Bahia Daylight Time', N'Bahia Standard Time', -180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (132, N'UTC-02', N'Coordinated Universal Time-02', N'UTC-02', N'UTC-02', -120, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (133, N'Mid-Atlantic Standard Time', N'Mid-Atlantic', N'Mid-Atlantic Daylight Time', N'Mid-Atlantic Standard Time', -120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (134, N'Azores Standard Time', N'Azores', N'Azores Daylight Time', N'Azores Standard Time', -60, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (135, N'Cape Verde Standard Time', N'Cape Verde Is.', N'Cape Verde Daylight Time', N'Cape Verde Standard Time', -60, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (136, N'Morocco Standard Time', N'Casablanca', N'Morocco Daylight Time', N'Morocco Standard Time', 0, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (137, N'UTC', N'Coordinated Universal Time', N'Coordinated Universal Time', N'Coordinated Universal Time', 0, 1, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (138, N'GMT Standard Time', N'Greenwich Mean Time : Dublin- Edinburgh- Lisbon- London', N'GMT Daylight Time', N'GMT Standard Time', 0, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (139, N'Greenwich Standard Time', N'Monrovia- Reykjavik', N'Greenwich Daylight Time', N'Greenwich Standard Time', 0, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (140, N'W. Europe Standard Time', N'Amsterdam- Berlin- Bern- Rome- Stockholm- Vienna', N'W. Europe Daylight Time', N'W. Europe Standard Time', 60, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (141, N'Central Europe Standard Time', N'Belgrade- Bratislava- Budapest- Ljubljana- Prague', N'Central Europe Daylight Time', N'Central Europe Standard Time', 60, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (142, N'Romance Standard Time', N'Brussels- Copenhagen- Madrid- Paris', N'Romance Daylight Time', N'Romance Standard Time', 60, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (143, N'Central European Standard Time', N'Sarajevo- Skopje- Warsaw- Zagreb', N'Central European Daylight Time', N'Central European Standard Time', 60, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (144, N'W. Central Africa Standard Time', N'West Central Africa', N'W. Central Africa Daylight Time', N'W. Central Africa Standard Time', 60, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (145, N'Namibia Standard Time', N'Windhoek', N'Namibia Daylight Time', N'Namibia Standard Time', 60, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (146, N'Jordan Standard Time', N'Amman', N'Jordan Daylight Time', N'Jordan Standard Time', 120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (147, N'GTB Standard Time', N'Athens- Bucharest', N'GTB Daylight Time', N'GTB Standard Time', 120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (148, N'Middle East Standard Time', N'Beirut', N'Middle East Daylight Time', N'Middle East Standard Time', 120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (149, N'Egypt Standard Time', N'Cairo', N'Egypt Daylight Time', N'Egypt Standard Time', 120, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (150, N'Syria Standard Time', N'Damascus', N'Syria Daylight Time', N'Syria Standard Time', 120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (151, N'South Africa Standard Time', N'Harare- Pretoria', N'South Africa Daylight Time', N'South Africa Standard Time', 120, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (152, N'FLE Standard Time', N'Helsinki- Kyiv- Riga- Sofia- Tallinn- Vilnius', N'FLE Daylight Time', N'FLE Standard Time', 120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (153, N'Turkey Standard Time', N'Istanbul', N'Turkey Daylight Time', N'Turkey Standard Time', 120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (154, N'Israel Standard Time', N'Jerusalem', N'Jerusalem Daylight Time', N'Jerusalem Standard Time', 120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (155, N'E. Europe Standard Time', N'E. Europe', N'E. Europe Daylight Time', N'E. Europe Standard Time', 120, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (156, N'Arabic Standard Time', N'Baghdad', N'Arabic Daylight Time', N'Arabic Standard Time', 180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (157, N'Kaliningrad Standard Time', N'Kaliningrad- Minsk', N'Kaliningrad Daylight Time', N'Kaliningrad Standard Time', 120, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (158, N'Arab Standard Time', N'Kuwait- Riyadh', N'Arab Daylight Time', N'Arab Standard Time', 180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (159, N'E. Africa Standard Time', N'Nairobi', N'E. Africa Daylight Time', N'E. Africa Standard Time', 180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (160, N'Iran Standard Time', N'Tehran', N'Iran Daylight Time', N'Iran Standard Time', 210, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (161, N'Arabian Standard Time', N'Abu Dhabi- Muscat', N'Arabian Daylight Time', N'Arabian Standard Time', 240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (162, N'Azerbaijan Standard Time', N'Baku', N'Azerbaijan Daylight Time', N'Azerbaijan Standard Time', 240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (163, N'Russian Standard Time', N'Moscow- St. Petersburg- Volgograd', N'Russian Daylight Time', N'Russian Standard Time', 180, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (164, N'Mauritius Standard Time', N'Port Louis', N'Mauritius Daylight Time', N'Mauritius Standard Time', 240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (165, N'Georgian Standard Time', N'Tbilisi', N'Georgian Daylight Time', N'Georgian Standard Time', 240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (166, N'Caucasus Standard Time', N'Caucasus Standard Time', N'Caucasus Daylight Time', N'Caucasus Standard Time', 240, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (167, N'Afghanistan Standard Time', N'Kabul', N'Afghanistan Daylight Time', N'Afghanistan Standard Time', 270, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (168, N'Pakistan Standard Time', N'Islamabad- Karachi', N'Pakistan Daylight Time', N'Pakistan Standard Time', 300, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (169, N'West Asia Standard Time', N'Tashkent', N'West Asia Daylight Time', N'West Asia Standard Time', 300, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (170, N'India Standard Time', N'Chennai- Kolkata- Mumbai- New Delhi', N'India Daylight Time', N'India Standard Time', 330, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (171, N'Sri Lanka Standard Time', N'Sri Jayawardenepura', N'Sri Lanka Daylight Time', N'Sri Lanka Standard Time', 330, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (172, N'Nepal Standard Time', N'Kathmandu', N'Nepal Daylight Time', N'Nepal Standard Time', 345, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (173, N'Central Asia Standard Time', N'Astana', N'Central Asia Daylight Time', N'Central Asia Standard Time', 360, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (174, N'Bangladesh Standard Time', N'Dhaka', N'Bangladesh Daylight Time', N'Bangladesh Standard Time', 360, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (175, N'Ekaterinburg Standard Time', N'Ekaterinburg', N'Ekaterinburg Daylight Time', N'Ekaterinburg Standard Time', 300, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (176, N'Myanmar Standard Time', N'Yangon (Rangoon)', N'Myanmar Daylight Time', N'Myanmar Standard Time', 390, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (177, N'SE Asia Standard Time', N'Bangkok- Hanoi- Jakarta', N'SE Asia Daylight Time', N'SE Asia Standard Time', 420, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (178, N'N. Central Asia Standard Time', N'Novosibirsk', N'N. Central Asia Daylight Time', N'N. Central Asia Standard Time', 360, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (179, N'China Standard Time', N'Beijing- Chongqing- Hong Kong- Urumqi', N'China Daylight Time', N'China Standard Time', 480, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (180, N'North Asia Standard Time', N'Krasnoyarsk', N'North Asia Daylight Time', N'North Asia Standard Time', 420, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (181, N'Singapore Standard Time', N'Kuala Lumpur- Singapore', N'Malay Peninsula Daylight Time', N'Malay Peninsula Standard Time', 480, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (182, N'W. Australia Standard Time', N'Perth', N'W. Australia Daylight Time', N'W. Australia Standard Time', 480, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (183, N'Taipei Standard Time', N'Taipei', N'Taipei Daylight Time', N'Taipei Standard Time', 480, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (184, N'Ulaanbaatar Standard Time', N'Ulaanbaatar', N'Ulaanbaatar Daylight Time', N'Ulaanbaatar Standard Time', 480, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (185, N'North Asia East Standard Time', N'Irkutsk', N'North Asia East Daylight Time', N'North Asia East Standard Time', 480, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (186, N'Tokyo Standard Time', N'Osaka- Sapporo- Tokyo', N'Tokyo Daylight Time', N'Tokyo Standard Time', 540, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (187, N'Korea Standard Time', N'Seoul', N'Korea Daylight Time', N'Korea Standard Time', 540, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (188, N'Cen. Australia Standard Time', N'Adelaide', N'Cen. Australia Daylight Time', N'Cen. Australia Standard Time', 570, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (189, N'AUS Central Standard Time', N'Darwin', N'AUS Central Daylight Time', N'AUS Central Standard Time', 570, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (190, N'E. Australia Standard Time', N'Brisbane', N'E. Australia Daylight Time', N'E. Australia Standard Time', 600, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (191, N'AUS Eastern Standard Time', N'Canberra- Melbourne- Sydney', N'AUS Eastern Daylight Time', N'AUS Eastern Standard Time', 600, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (192, N'West Pacific Standard Time', N'Guam- Port Moresby', N'West Pacific Daylight Time', N'West Pacific Standard Time', 600, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (193, N'Tasmania Standard Time', N'Hobart', N'Tasmania Daylight Time', N'Tasmania Standard Time', 600, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (194, N'Yakutsk Standard Time', N'Yakutsk', N'Yakutsk Daylight Time', N'Yakutsk Standard Time', 540, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (195, N'Central Pacific Standard Time', N'Solomon Is.- New Caledonia', N'Central Pacific Daylight Time', N'Central Pacific Standard Time', 660, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (196, N'Vladivostok Standard Time', N'Vladivostok', N'Vladivostok Daylight Time', N'Vladivostok Standard Time', 600, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (197, N'New Zealand Standard Time', N'Auckland- Wellington', N'New Zealand Daylight Time', N'New Zealand Standard Time', 720, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (198, N'UTC+12', N'Coordinated Universal Time+12', N'UTC+12', N'UTC+12', 720, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (199, N'Fiji Standard Time', N'Fiji', N'Fiji Daylight Time', N'Fiji Standard Time', 720, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (200, N'Magadan Standard Time', N'Magadan', N'Magadan Daylight Time', N'Magadan Standard Time', 660, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (201, N'Kamchatka Standard Time', N'Petropavlovsk-Kamchatsky - Old', N'Kamchatka Daylight Time', N'Kamchatka Standard Time', 720, 0, NULL, 1)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (202, N'Tonga Standard Time', N'Nuku''alofa', N'Tonga Daylight Time', N'Tonga Standard Time', 780, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (203, N'Samoa Standard Time', N'Samoa', N'Samoa Daylight Time', N'Samoa Standard Time', 780, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (204, N'Mexico Standard Time 2', N'Chihuahua- La Paz- Mazatlan - Old', N'Mexico Daylight Time 2', N'Mexico Standard Time 2', 0, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (205, N'Mexico Standard Time ', N'Guadalajara- Mexico City- Monterrey - Old', N'Mexico Daylight Time', N'Mexico Standard Time', 0, 0, NULL, 0)
GO
INSERT [Types].[GlobalizationZone] ([ZoneID], [SystemZoneID], [DisplayName], [DaylightName], [StandardName], [GMTOffset], [IsDefault], [ManualOffset], [IsDaylightTime]) VALUES (206, N'Armenian Standard Time', N'Yerevan', N'Armenian Daylight Time', N'Armenian Standard Time', 0, 0, NULL, 0)
GO


-- [Device].[Types.DeviceType]
INSERT INTO [Device].[Types.DeviceType] ([TypeID], [Name]) VALUES (10, 'Hydra2')
INSERT INTO [Device].[Types.DeviceType] ([TypeID], [Name]) VALUES (20, 'XCI')
INSERT INTO [Device].[Types.DeviceType] ([TypeID], [Name]) VALUES (21, 'XCI-WIFI')

--[WeatherAlgorithms]
--INSERT INTO [Weather].[WeatherAlgorithms] ([AlgorithmID], [Name]) VALUES (10, 'OLD CyberRain (P1)')

