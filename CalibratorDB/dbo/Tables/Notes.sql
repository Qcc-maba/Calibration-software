CREATE TABLE [dbo].[Notes] (
    [ID]          INT            NOT NULL,
    [Department]  INT            NOT NULL,
    [NoteHeb]     VARCHAR (1000) NOT NULL,
    [NoteEng]     VARCHAR (1000) NOT NULL,
    [NoteNameHeb] VARCHAR (50)   NULL,
    [NoteNameEng] VARCHAR (50)   NULL
);

