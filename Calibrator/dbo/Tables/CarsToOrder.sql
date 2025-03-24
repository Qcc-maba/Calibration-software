CREATE TABLE [dbo].[CarsToOrder] (
    [CarId]         INT           NOT NULL,
    [OrderNumber]   NCHAR (12)    NOT NULL,
    [AssignDate]    DATETIME2 (0) NOT NULL,
    [AssignQuater0] BIT           NULL,
    [AssignQuater1] BIT           NULL,
    [AssignQuater2] BIT           NULL,
    [AssignQuater3] BIT           NULL,
    CONSTRAINT [PK_CarsToOrder] PRIMARY KEY CLUSTERED ([AssignDate] ASC, [OrderNumber] ASC, [CarId] ASC)
);

