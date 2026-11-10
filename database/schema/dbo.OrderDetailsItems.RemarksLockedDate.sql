/*
    dbo.OrderDetailsItems.RemarksLockedDate                                                MBA-848
    ---------------------------------------------------------------------------------------------
    When set, the report's remarks are read-only: dbo.SaveCalibrationRemarks refuses to change them.
    Remarks stay editable until the report is signed (Nofar, MBA-848, 01/11); opening the preview or
    downloading the PDF does not lock them.

    Why a column of its own: nothing on the server records the signature today. The wizard keeps
    "signed" only in the browser's IndexedDB, and the FirstSignature / SecondSignature report statuses
    exist but are never set - CalibrationReportStatusId is NULL on all 5,917 STAGE lines (01/11).
    The app sets and clears this through dbo.SetCalibrationRemarksLock.

    NULL = editable, so every existing line stays editable. Replayable.
*/
IF COL_LENGTH('dbo.OrderDetailsItems', 'RemarksLockedDate') IS NULL
    ALTER TABLE dbo.OrderDetailsItems ADD RemarksLockedDate DATETIME2(0) NULL;
GO
