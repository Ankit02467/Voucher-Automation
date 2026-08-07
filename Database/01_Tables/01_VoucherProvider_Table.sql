/* ============================================================
   Table : VoucherProvider_Table
   Module: Voucher
   Note  : New object for DSL_CMS_OSS. Existing Voucher_Table /
           sp_Voucher_Table (website CMS content) are NOT touched.
   ============================================================ */
USE DSL_New;
GO

IF OBJECT_ID('dbo.VoucherProvider_Table', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VoucherProvider_Table
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        Name          NVARCHAR(150)     NOT NULL,
        Category      NVARCHAR(100)     NULL,
        ContactPerson NVARCHAR(150)     NULL,
        ContactEmail  NVARCHAR(150)     NULL,
        ContactNo     NVARCHAR(50)      NULL,
        Status        CHAR(1)           NOT NULL CONSTRAINT DF_VoucherProvider_Status DEFAULT ('A'),
        AddedBy       INT               NULL,
        AddedDate     DATETIME          NOT NULL CONSTRAINT DF_VoucherProvider_AddedDate DEFAULT (GETDATE()),
        ModifiedBy    INT               NULL,
        ModifiedDate  DATETIME          NULL,
        CONSTRAINT PK_VoucherProvider_Table PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_VoucherProvider_Name UNIQUE (Name),
        CONSTRAINT CK_VoucherProvider_Status CHECK (Status IN ('A','I'))
    );

    CREATE NONCLUSTERED INDEX IX_VoucherProvider_Category
        ON dbo.VoucherProvider_Table (Category) INCLUDE (Name, Status);

    PRINT 'Created dbo.VoucherProvider_Table';
END
ELSE
    PRINT 'dbo.VoucherProvider_Table already exists - skipped';
GO
