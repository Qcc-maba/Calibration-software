CREATE TABLE [dbo].[InstrCorrections] (
    [ID]            INT             NOT NULL,
    [RangeStart]    NUMERIC (18, 6) NULL,
    [RangeStop]     NUMERIC (18, 6) NULL,
    [Note]          VARCHAR (300)   NULL,
    [InstrumentId]  INT             NOT NULL,
    [MeasurementId] INT             NOT NULL,
    [UnitID]        INT             NOT NULL,
    [DateAdded]     DATETIME        NULL,
    [CorVersion]    INT             NOT NULL,
    [Department]    INT             NULL,
    [Equation]      VARCHAR (300)   NOT NULL
);

