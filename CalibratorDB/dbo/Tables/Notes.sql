CREATE TABLE [dbo].[Notes] (
    [ID]          INT            NOT NULL,
    [Department]  INT            NOT NULL,
    [NoteHeb]     NVARCHAR (1000) NOT NULL,
    [NoteEng]     NVARCHAR (1000) NOT NULL,
    [NoteNameHeb] NVARCHAR (50)   NULL,
    [NoteNameEng] NVARCHAR (50)   NULL
);

