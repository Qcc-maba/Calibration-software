MERGE INTO [dbo].[MeasurementDeviceUnits] AS dest
USING (
SELECT 
 *
FROM (
VALUES
(N'nm', N'nm', N'nanometre', N'נ"מ', N'נ"מ', N'ננומטר', NULL, NULL, 1, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'µm', N'µm', N'micrometre', N'מק"מ', N'מק"מ', N'מיקרומטר', NULL, NULL, 2, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'mm', N'mm', N'millimetre', N'מ"מ', N'מ"מ', N'מילימטר', NULL, NULL, 4, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'cm', N'cm', N'centimetre', N'ס"מ', N'ס"מ', N'סנטימטר', NULL, NULL, 5, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'dm', N'dm', N'decimetre', N'דצ''''מ', N'דצ''''מ', N'דצימטר', NULL, NULL, 6, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'm', N'm', N'meter', N'מ', N'מ', N'מטר', NULL, NULL, 7, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'pm', N'pm', N'picometre', N'פק"מ', N'פק"מ', N'פיקומטר', NULL, NULL, 8, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'dam', N'dam', N'decametre', N'דק"מ', N'דק"מ', N'דקהמטר', NULL, NULL, 9, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'hm', N'hm', N'hectometre', N'הק"מ', N'הק"מ', N'הקטומטר', NULL, NULL, 10, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'km', N'km', N'kilometre', N'ק"מ', N'ק"מ', N'קילומטר', NULL, NULL, 11, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'"', N'"', N'inch', N'אינץ'' ', N'אינץ'' ', N'אינץ'' ', NULL, NULL, 12, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 10)
,(N'K', N'K', N'Kelvin', N'K', N'K', N'קלווין ', NULL, NULL, 13, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)
,(N'°C', N'°C', N'Celsius', N'°C', N'°C', N'מעלות צלזיוס', NULL, NULL, 14, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)
,(N'°F', N'°F', N'Fahrenheit', N'°F', N'°F', N'מעלות פרנהייט', NULL, NULL, 17, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)
--,(N'°Ra', N'°Ra', N'Rankine', N'°Ra', N'°Ra', N'מעלות רנקין', NULL, NULL, 18, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)
--,(N'°Ré', N'°Re', N'Réaumur', N'°Re', N'°Ré', N'מעלות ראומיר', NULL, NULL, 19, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)
--,(N'°N', N'°N', N'Newton', N'°N', N'°N', N'מעלות ניוטון', NULL, NULL, 20, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)
--,(N'°Rø', N'°Ro', N'Rømer', N'°Ro', N'°Rø', N'מעלות רומר', NULL, NULL, 21, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)
--,(N'°De', N'°De', N'Delisle', N'°De', N'°De', N'מעלות דליסל', NULL, NULL, 22, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)
,(N'Pa', N'Pa', N'Pascal', N'Pa', N'Pa', N'פסקל', NULL, N'1 Pa = 1 N/m² ', 23, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'bar', N'bar', N'Bar', N'bar', N'bar', N'באר', NULL, N'1 bar=106 dyn/cm² ', 24, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'at', N'at', N'technical atmosphere', N'at', N'at', N'אטמוספרה  טכנית', NULL, N'1 at = 1 kgf/cm²', 25, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'atm', N'atm', N'atmosphere', N'atm', N'atm', N'אטמוספירה', NULL, N'1 atm =1.013 25 bar ', 26, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'torr', N'torr', N'Torr', N'טור', N'טור', N'טור', NULL, N'1 torr = 1 mmHg', 27, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'mmHg', N'mmHg', N'millimetres of mercury', N'mmHg', N'mmHg', N'מילימטר של כספית', NULL, N'1 mmHg = 1 torr', 28, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'psi', N'psi', N'pound-force per square inch', N'פסיי', N'פסיי', N'ליברה לאינץ'' מרובע ', NULL, N'1 lbf/in² = 6,894.75729 pascals (Pa)', 29, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'inHg', N'inHg', N'inch of mercury', N'inHg', N'inHg', N'אינץ'' של כספית', NULL, N'1 inHg = 3,386.389 pascals at 0 °C.', 30, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'cmH2O', N'cmH2O', N'centimetre of water ', N'cmH2O', N'cmH2O', N'סנטימטר של מים', NULL, N'1 cmH2O = 98.0638 pascals at 4 °C ', 31, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'mbar', N'mbar', N'millibar', N'mbar', N'mbar', N'מיליבאר', NULL, N' mbar = 0.001 bar = 100 Pa = 1 000 dyn/cm² ', 32, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'kPa', N'kPa', N'kilopascal', N'kPa', N'kPa', N'קילופסקל', NULL, N'1 kilopascal (kPa) = 1000 Pa = 10 hPa', 33, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'hPa', N'hPa', N'hectopascal', N'hPa', N'hPa', N'הקטופסקל', NULL, N'1 hectopascal (hPa) = 100 Pa = 1 mbar. ', 34, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'%', N'%', N'percent', N'%', N'%', N'אחוז', NULL, N'Parts per hundred (denoted by ''%'' and very rarely ''pph'')', 35, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 9)
,(N'‰', N'per mille', N'parts per mille', N'per mille', N'‰', N'פרומיל ', NULL, N'A per mil or per mille (also spelled permil or per mill) (Latin, literally meaning ''for (every) thousand'') is a tenth of a percent or one part per thousand. It is written with the sign ‰ (Unicode U+2030)., which looks like a percent sign (%) with an extra 0 at the end. It can be seen as a stylized form of the three zeros in the denominator, although it originates from an alteration of the percent sign.', 36, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 9)
,(N'%RH', N'%RH', N'Relative humidity', N'%RH', N'%RH', N'לחות יחסית', NULL, N'Relative humidity is defined as the ratio of the partial pressure of water vapor in a gaseous mixture of air and water to the saturated vapor pressure of water at a given temperature.', 37, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 9)
,(N'Pa a', N'Pa a', N'Pascal absolute', N'Pa a', N'Pa a', N'פסקל אבסולוט', NULL, N'1 Pa = 1 N/m² ', 38, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'kPa a', N'kPa a', N'kilopascal absolute', N'kPa a', N'kPa a', N'קילופסקל אבסולוט', NULL, N'1 kilopascal (kPa) = 1000 Pa = 10 hPa', 39, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'at a', N'at a', N'technical atmosphere absolute', N'at a', N'at a', N'אטמוספרה טכנית אבסולוט', NULL, N'1 at = 1 kgf/cm²', 40, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'atm a', N'atm a', N'atmosphere absolute', N'atm a', N'atm a', N'אטמוספירה אבסולוט', NULL, N'1 atm =1.013 25 bar ', 41, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'torr a', N'torr a', N'Torr absolute', N'torr a', N'torr a', N'טור אבסולוט', NULL, N'1 torr = 1 mmHg', 42, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'mmHg a', N'mmHg a', N'millimetres of mercury absolute', N'mmHg a', N'mmHg a', N'מילימטר של כספית אבסולוט', NULL, N'1 mmHg = 1 torr', 43, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'psi a', N'psi a', N'pound-force per square inch absolute', N'psi a', N'psi a', N'ליברה לאינץ'' מרובע אבסולוט ', NULL, N'1 lbf/in² = 6,894.75729 pascals (Pa)', 44, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'inHg a', N'inHg a', N'inch of mercury absolute', N'inHg a', N'inHg a', N'אינץ'' של כספית אבסולוט', NULL, N'1 inHg = 3,386.389 pascals at 0 °C.', 45, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'cmH2O a', N'cmH2O a', N'centimetre of water absolute', N'cmH2O a', N'cmH2O a', N'סנטימטר של מים אבסולוט', NULL, N'1 cmH2O = 98.0638 pascals at 4 °C ', 46, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'mbar a', N'mbar a', N'millibar absolute', N'mbar a', N'mbar a', N'מיליבאר אבסולוט', NULL, N' mbar = 0.001 bar = 100 Pa = 1 000 dyn/cm² ', 47, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'bar a', N'bar a', N'Bar absolute', N'bar a', N'bar a', N'באר אבסולוט', NULL, N'1 bar=106 dyn/cm² ', 48, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'hPa a', N'hPa a', N'hectopascal absolute', N'hPa a', N'hPa a', N'הקטופסקל אבסולוט', NULL, N'1 hectopascal (hPa) = 100 Pa = 1 mbar. ', 49, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 2)
,(N'mV', N'mV', N'millivolt', N'mV', N'mV', N'מיליוולט', NULL, N'A unit of potential difference equal to one thousandth (10e-3) of a volt.', 50, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 3)
,(N'V', N'V', N'volt', N'V', N'V', N'וולט', NULL, N'The volt is defined as the potential difference across a conductor when a current of one ampere dissipates one watt of power. Hence, it is the base SI representation m2 · kg · s-3 · A-1', 51, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 3)
,(N'ppm', N'ppm', N'parts per million', N'ppm', N'ppm', N'חלקים למיליון', NULL, N'Parts per million ("ppm") denotes one particle of a given substance for every 999,999 other particles. This is roughly equivalent to one drop of ink in a 150 litre (40 gallon) drum of water, or one second per 280 hours (11 days, 16 hours). One part in 106 — a precision of 0.0001%.', 52, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 9)
,(N'Ω', N'Ohm', N'Ohm', N'אוהם', N'Ω', N'אוהם', NULL, N'An ohm is the electrical resistance offered by a current-carrying element that produces a voltage drop of one volt when a current of one ampere is flowing through it.', 53, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 3)
,(N'ppb', N'ppb', N'parts per billion', N'ppb', N'ppb', N'חלקים לביליון', NULL, N'One part per billion (ppb): Denotes one part per 1,000,000,000 parts, one part in 109, and a value of 1 × 10–9. This is equivalent to 1 drop of water diluted into 250 chemical drums (50 m³), or one second of time in approximately 31.7 years. ', 55, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 9)
,(N'ppt', N'ppt', N'parts per trillion', N'ppt', N'ppt', N'חלקים לטריליון', NULL, N'One part per trillion (ppt): Denotes one part per 1,000,000,000,000 parts, one part in 1012, and a value of 1 × 10–12. This is equivalent to 1 drop of water diluted into 20, two-meter-deep Olympic-size swimming pools (50,000 m³), or one second of time in approximately 31,700 years. ', 56, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 9)
,(N'Hz', N'Hz', N'Hertz', N'הרץ', N'הרץ', N'הרץ', NULL, N'Number of cycles per seconds', 57, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 3)
,(N'°C D.P', N'°C D.P', N'Dew Point', N'Dew Point', N'נקודת טל', N'נקודת טל', NULL, NULL, 60, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 9)
--,(N'RPM', N'RPM', N'RPM', N'RPM', N'מד סיבובים', N'מד סיבובים', NULL, NULL, 61, CAST(N'2025-09-02T19:03:17.0000000' AS DateTime2), NULL, 0, 0, 6)

) ds ( [ShortNameEn], [ShortNameEnAsc], [LongNameEn], [ShortNameHeAsc], [ShortNameHe], [LongNameHe], [MeasurementDeviceUnitGroupId], [Note], [MeasurementDeviceUnitSourceId], [CreatedDate], [UpdatedDate], [IsDeleted], [UpdateUserID], [MainCategoryId])


	) AS source
	ON dest.[LongNameEn] = source.[LongNameEn]
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[ShortNameEn] = source.[ShortNameEn]
			,dest.[ShortNameEnAsc] = source.[ShortNameEnAsc]
			,dest.[ShortNameHeAsc] = source.[ShortNameHeAsc]
			,dest.[ShortNameHe] = source.[ShortNameHe]
			,dest.[LongNameHe] = source.[LongNameHe]
			,dest.[MeasurementDeviceUnitGroupId] = source.[MeasurementDeviceUnitGroupId]
			,dest.[Note] = source.[Note]
			,dest.[MeasurementDeviceUnitSourceId] = source.[MeasurementDeviceUnitSourceId]
			,dest.[CreatedDate] = source.[CreatedDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[IsDeleted] = source.[IsDeleted]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[MainCategoryId] = source.[MainCategoryId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [ShortNameEn]
			,[ShortNameEnAsc]
			,[LongNameEn]
			,[ShortNameHeAsc]
			,[ShortNameHe]
			,[LongNameHe]
			,[MeasurementDeviceUnitGroupId]
			,[Note]
			,[MeasurementDeviceUnitSourceId]
			,[CreatedDate]
			,[UpdatedDate]
			,[IsDeleted]
			,[UpdateUserID]
			,[MainCategoryId]
			)
		VALUES (
			 source.[ShortNameEn]
			,source.[ShortNameEnAsc]
			,source.[LongNameEn]
			,source.[ShortNameHeAsc]
			,source.[ShortNameHe]
			,source.[LongNameHe]
			,source.[MeasurementDeviceUnitGroupId]
			,source.[Note]
			,source.[MeasurementDeviceUnitSourceId]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[IsDeleted]
			,source.[UpdateUserID]
			,source.[MainCategoryId]
			);
