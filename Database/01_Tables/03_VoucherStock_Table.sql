/* ============================================================
   Table : VoucherStock_Table
   Module: Voucher  (voucher-data.aspx / voucher-status.aspx)

   NAMED VoucherStock_Table (not Voucher_Table) on purpose:
   dbo.Voucher_Table already exists in DSL_New and holds the
   public website's voucher CONTENT (Name/Price1/Price2/ImageUrl).
   That table and sp_Voucher_Table are left untouched.
   ============================================================ */
USE DSL_New;
GO

IF OBJECT_ID('dbo.VoucherStock_Table', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VoucherStock_Table
    (
        Id                INT IDENTITY(1,1) NOT NULL,
        ProviderId        INT               NOT NULL,
        ProductId         INT               NOT NULL,
        VoucherCode       NVARCHAR(100)     NOT NULL,
        ExpiryDate        DATE              NULL,
        DealerName        NVARCHAR(150)     NULL,
        SaleDate          DATE              NULL,
        Status            NVARCHAR(20)      NOT NULL CONSTRAINT DF_VoucherStock_Status DEFAULT ('Unused'),
        VoucherCheckDate  DATETIME          NULL,
        CheckedBy         NVARCHAR(100)     NULL,
        Remarks           NVARCHAR(500)     NULL,
        AddedBy           INT               NULL,
        AddedDate         DATETIME          NOT NULL CONSTRAINT DF_VoucherStock_AddedDate DEFAULT (GETDATE()),
        ModifiedBy        INT               NULL,
        ModifiedDate      DATETIME          NULL,
        CONSTRAINT PK_VoucherStock_Table PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VoucherStock_Provider FOREIGN KEY (ProviderId)
            REFERENCES dbo.VoucherProvider_Table (Id),
        CONSTRAINT FK_VoucherStock_Product FOREIGN KEY (ProductId)
            REFERENCES dbo.VoucherProduct_Table (Id),
        CONSTRAINT UQ_VoucherStock_Code UNIQUE (VoucherCode),
        CONSTRAINT CK_VoucherStock_Status CHECK (Status IN ('Used','Unused','Expired'))
    );

    CREATE NONCLUSTERED INDEX IX_VoucherStock_Provider_Status
        ON dbo.VoucherStock_Table (ProviderId, Status) INCLUDE (ProductId, VoucherCode, SaleDate);

    CREATE NONCLUSTERED INDEX IX_VoucherStock_SaleDate
        ON dbo.VoucherStock_Table (SaleDate);

    CREATE NONCLUSTERED INDEX IX_VoucherStock_CheckedBy
        ON dbo.VoucherStock_Table (CheckedBy);

    PRINT 'Created dbo.VoucherStock_Table';
END
ELSE
    PRINT 'dbo.VoucherStock_Table already exists - skipped';
GO
