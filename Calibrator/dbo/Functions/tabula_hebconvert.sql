CREATE FUNCTION [dbo].[tabula_hebconvert]
(@s NVARCHAR (1000) NULL)
RETURNS NVARCHAR (1000)
AS
 EXTERNAL NAME [hebutils].[eshbel_priority.PriorityHebUtil].[HebrewFilter]

