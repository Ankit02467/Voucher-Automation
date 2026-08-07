/* ============================================================
   Table : VoucherProduct_Table
   Module: Voucher  (manage-product.aspx)
   ============================================================ */
USE DSL_New;
GO

IF OBJECT_ID('dbo.VoucherProduct_Table', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VoucherProduct_Table
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        ProviderId   INT               NOT NULL,
        Name         NVARCHAR(150)     NOT NULL,
        ValidityDays INT               NULL,
        Status       CHAR(1)           NOT NULL CONSTRAINT DF_VoucherProduct_Status DEFAULT ('A'),
        AddedBy      INT               NULL,
        AddedDate    DATETIME          NOT NULL CONSTRAINT DF_VoucherProduct_AddedDate DEFAULT (GETDATE()),
        ModifiedBy   INT               NULL,
        ModifiedDate DATETIME          NULL,
        CONSTRAINT PK_VoucherProduct_Table PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VoucherProduct_Provider FOREIGN KEY (ProviderId)
            REFERENCES dbo.VoucherProvider_Table (Id),
        CONSTRAINT UQ_VoucherProduct_Provider_Name UNIQUE (ProviderId, Name),
        CONSTRAINT CK_VoucherProduct_Status CHECK (Status IN ('A','I'))
    );

    CREATE NONCLUSTERED INDEX IX_VoucherProduct_ProviderId
        ON dbo.VoucherProduct_Table (ProviderId) INCLUDE (Name, ValidityDays, Status);

    PRINT 'Created dbo.VoucherProduct_Table';
END
ELSE
    PRINT 'dbo.VoucherProduct_Table already exists - skipped';
GO
