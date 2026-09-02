/* ============================================================
   Remarks on a voucher - a log, not a field.

   VoucherStock_Table already has a Remarks column, encrypted
   along with everything else in 08_Encryption. Nothing has ever
   written to it, and it could not serve this anyway: one column
   holds one remark, and what is wanted here is every remark
   anybody has left, each with who left it and when - the way
   VoucherHistory_Table holds every change rather than the last
   one.

   So a table of its own. The old column is left exactly where it
   is, unread and unwritten, in line with "retire, never delete".

   Remark is VARBINARY under VoucherDataKey, like the voucher code
   and the candidate name beside it. A remark can name a candidate
   or a dealer, so it is not the one piece of voucher text that
   should sit in the clear.

   RoleName is stored rather than looked up. It is the role the
   writer held when they wrote it; reading it back off the user
   today would relabel every old remark the day somebody changes
   role. The name is joined live from User_Table, because a person
   correcting the spelling of their own name means it everywhere.

   Run order: after 08_Encryption (the key must exist).
   Re-runnable.
   ============================================================ */
USE DSL_New;
GO

SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.VoucherRemark_Table', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VoucherRemark_Table
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        VoucherId   INT               NOT NULL,
        Remark      VARBINARY(MAX)    NULL,       -- ciphertext under VoucherDataKey
        RoleName    NVARCHAR(50)      NULL,       -- the role held when it was written
        CreatedBy   INT               NULL,       -- User_Table.Id
        CreatedDate DATETIME          NOT NULL
            CONSTRAINT DF_VoucherRemark_CreatedDate DEFAULT (GETDATE()),
        CONSTRAINT PK_VoucherRemark_Table PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VoucherRemark_Voucher FOREIGN KEY (VoucherId)
            REFERENCES dbo.VoucherStock_Table (Id)
    );
    PRINT 'Created dbo.VoucherRemark_Table';
END
ELSE
    PRINT 'dbo.VoucherRemark_Table already there';
GO

/* Every read is "the remarks on this voucher, oldest first", and the grid asks
   it once per row for the latest one. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'IX_VoucherRemark_Voucher'
                  AND object_id = OBJECT_ID('dbo.VoucherRemark_Table'))
BEGIN
    CREATE INDEX IX_VoucherRemark_Voucher
        ON dbo.VoucherRemark_Table (VoucherId, Id);
    PRINT 'Created IX_VoucherRemark_Voucher';
END
GO

PRINT 'VoucherRemark_Table ready';
GO
