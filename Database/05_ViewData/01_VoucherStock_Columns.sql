/* ============================================================
   View Data screen - schema additions.

   New columns on VoucherStock_Table for the 15 grid fields, plus a
   history table and the Voucher module roles.
   Nothing existing is dropped; every step is guarded so the script
   can be re-run safely.
   ============================================================ */
USE DSL_New;
GO

/* ---------- 1. extra voucher columns ---------- */
IF COL_LENGTH('dbo.VoucherStock_Table', 'DealerName2') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD DealerName2 NVARCHAR(150) NULL;
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'SaleDate2') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD SaleDate2 DATE NULL;
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'UsedDate') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD UsedDate DATE NULL;          -- Voucher Used date
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'CandidateName') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD CandidateName NVARCHAR(150) NULL;
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'ExamDate') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD ExamDate DATE NULL;
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'ExamMode') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD ExamMode NVARCHAR(50) NULL;
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'AssignedTo') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD AssignedTo INT NULL;         -- User_Table.Id of the student
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'AssignedBy') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD AssignedBy INT NULL;
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'AssignedDate') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD AssignedDate DATETIME NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VoucherStock_AssignedTo')
    CREATE NONCLUSTERED INDEX IX_VoucherStock_AssignedTo
        ON dbo.VoucherStock_Table (AssignedTo) INCLUDE (ProductId, Status);
GO

/* ---------- 2. status history ---------- */
IF OBJECT_ID('dbo.VoucherHistory_Table', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VoucherHistory_Table
    (
        Id               INT IDENTITY(1,1) NOT NULL,
        VoucherId        INT               NOT NULL,
        ProductId        INT               NULL,
        VoucherCode      NVARCHAR(100)     NULL,
        OldStatus        NVARCHAR(20)      NULL,
        Status           NVARCHAR(20)      NULL,
        CheckedBy        NVARCHAR(100)     NULL,
        VoucherCheckDate DATETIME          NULL,
        ChangedBy        INT               NULL,
        ChangedDate      DATETIME          NOT NULL
            CONSTRAINT DF_VoucherHistory_ChangedDate DEFAULT (GETDATE()),
        CONSTRAINT PK_VoucherHistory_Table PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VoucherHistory_Voucher FOREIGN KEY (VoucherId)
            REFERENCES dbo.VoucherStock_Table (Id)
    );

    CREATE NONCLUSTERED INDEX IX_VoucherHistory_Voucher
        ON dbo.VoucherHistory_Table (VoucherId, ChangedDate DESC);

    PRINT 'Created dbo.VoucherHistory_Table';
END
GO

/* ---------- 3. Voucher module roles ----------
   Follows the existing UserTypeMaster pattern:
   TypeId = module, UserTypeName = role. Account=1, Booking=2, Training=3.
   ------------------------------------------------ */
SET IDENTITY_INSERT dbo.UserTypeMaster ON;

INSERT INTO dbo.UserTypeMaster (Id, TypeId, TypeName, UserTypeName, Status)
SELECT v.Id, 4, 'Voucher', v.RoleName, 1
FROM (VALUES
    (10, 'Voucher Admin'),
    (11, 'Voucher Sub Admin'),
    (12, 'Voucher Team'),
    (13, 'Voucher Student')
) AS v(Id, RoleName)
WHERE NOT EXISTS (SELECT 1 FROM dbo.UserTypeMaster u WHERE u.Id = v.Id);

SET IDENTITY_INSERT dbo.UserTypeMaster OFF;
GO

SELECT Id, TypeId, TypeName, UserTypeName FROM dbo.UserTypeMaster WHERE TypeId = 4 ORDER BY Id;
GO
