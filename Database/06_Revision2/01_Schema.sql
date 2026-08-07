/* ============================================================
   Revision 2 schema.

   1. Status may now be NULL - a freshly uploaded voucher has no
      status until someone sets one.
   2. Dealers move to a child table so any number of
      "Dealer Name / Sale Date" pairs can be added per voucher.
   3. Move / reassign flow between student and sub-admin.
   ============================================================ */
USE DSL_New;
GO

/* ---------- 1. status may be NULL ---------- */
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_VoucherStock_Status')
    ALTER TABLE dbo.VoucherStock_Table DROP CONSTRAINT CK_VoucherStock_Status;
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = 'DF_VoucherStock_Status')
    ALTER TABLE dbo.VoucherStock_Table DROP CONSTRAINT DF_VoucherStock_Status;
GO

ALTER TABLE dbo.VoucherStock_Table ALTER COLUMN Status NVARCHAR(20) NULL;
GO

ALTER TABLE dbo.VoucherStock_Table WITH CHECK
    ADD CONSTRAINT CK_VoucherStock_Status
    CHECK (Status IS NULL OR Status IN ('Used','Unused','Expired','Invalid'));
GO

/* ---------- 2. dealers child table ---------- */
IF OBJECT_ID('dbo.VoucherDealer_Table', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VoucherDealer_Table
    (
        Id         INT IDENTITY(1,1) NOT NULL,
        VoucherId  INT               NOT NULL,
        Seq        INT               NOT NULL,   -- 1 = Dealer Name 1, 2 = Dealer Name 2 ...
        DealerName NVARCHAR(150)     NULL,
        SaleDate   DATE              NULL,
        CONSTRAINT PK_VoucherDealer_Table PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_VoucherDealer_Seq UNIQUE (VoucherId, Seq),
        CONSTRAINT FK_VoucherDealer_Voucher FOREIGN KEY (VoucherId)
            REFERENCES dbo.VoucherStock_Table (Id)
    );
    PRINT 'Created dbo.VoucherDealer_Table';
END
GO

/* carry the existing two dealer slots across, once */
IF NOT EXISTS (SELECT 1 FROM dbo.VoucherDealer_Table)
BEGIN
    INSERT INTO dbo.VoucherDealer_Table (VoucherId, Seq, DealerName, SaleDate)
    SELECT Id, 1, DealerName, SaleDate
    FROM dbo.VoucherStock_Table
    WHERE DealerName IS NOT NULL OR SaleDate IS NOT NULL;

    INSERT INTO dbo.VoucherDealer_Table (VoucherId, Seq, DealerName, SaleDate)
    SELECT Id, 2, DealerName2, SaleDate2
    FROM dbo.VoucherStock_Table
    WHERE DealerName2 IS NOT NULL OR SaleDate2 IS NOT NULL;

    PRINT 'Migrated existing dealer values';
END
GO

/* ---------- 3. move / reassign ---------- */
IF COL_LENGTH('dbo.VoucherStock_Table', 'IsMoved') IS NULL
    ALTER TABLE dbo.VoucherStock_Table
        ADD IsMoved BIT NOT NULL CONSTRAINT DF_VoucherStock_IsMoved DEFAULT (0);
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'MovedDate') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD MovedDate DATETIME NULL;
GO
IF COL_LENGTH('dbo.VoucherStock_Table', 'MovedBy') IS NULL
    ALTER TABLE dbo.VoucherStock_Table ADD MovedBy INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VoucherStock_Moved')
    CREATE NONCLUSTERED INDEX IX_VoucherStock_Moved
        ON dbo.VoucherStock_Table (IsMoved, AssignedTo);
GO

/* history records the move / reassign steps as well as status changes */
IF COL_LENGTH('dbo.VoucherHistory_Table', 'Activity') IS NULL
    ALTER TABLE dbo.VoucherHistory_Table ADD Activity NVARCHAR(40) NULL;
GO
IF COL_LENGTH('dbo.VoucherHistory_Table', 'AssignedToName') IS NULL
    ALTER TABLE dbo.VoucherHistory_Table ADD AssignedToName NVARCHAR(150) NULL;
GO

UPDATE dbo.VoucherHistory_Table SET Activity = 'Status Update' WHERE Activity IS NULL;
GO

SELECT Dealers = (SELECT COUNT(*) FROM dbo.VoucherDealer_Table),
       NullStatus = (SELECT COUNT(*) FROM dbo.VoucherStock_Table WHERE Status IS NULL);
GO
