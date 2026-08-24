/* ============================================================
   Proc  : Sp_VoucherProvider_Table
   Screen: voucher-status.aspx
   Called: VoucherDAL.GetProviderSummary / GetAllProvider / GetProvider

   All parameters are NVARCHAR because the DAL passes every value
   as a string; conversion happens inside using TRY_CONVERT.
   ============================================================ */
USE DSL_New;
GO

IF OBJECT_ID('dbo.Sp_VoucherProvider_Table', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Sp_VoucherProvider_Table;
GO

CREATE PROCEDURE dbo.Sp_VoucherProvider_Table
(
    @Action   NVARCHAR(50),
    @Id       NVARCHAR(50)  = NULL,
    @Name     NVARCHAR(150) = NULL,
    @Category NVARCHAR(100) = NULL,
    @Status   NVARCHAR(20)  = NULL,
    @FromDate NVARCHAR(30)  = NULL,
    @ToDate   NVARCHAR(30)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdInt INT   = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @From  DATE  = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@FromDate)), ''));
    DECLARE @To    DATE  = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ToDate)),   ''));

    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), '');
    SET @Status   = NULLIF(LTRIM(RTRIM(@Status)),   '');

    /* ---- Provider wise Used / Unused summary ---- */
    IF @Action = 'SelectSummary'
    BEGIN
        SELECT
            p.Id,
            p.Name,
            p.Category,
            p.Status,
            TotalVoucher  = COUNT(v.Id),
            UsedVoucher   = SUM(CASE WHEN v.Status = 'Used'    THEN 1 ELSE 0 END),
            UnusedVoucher = SUM(CASE WHEN v.Status = 'Unused'  THEN 1 ELSE 0 END),
            ExpiredVoucher= SUM(CASE WHEN v.Status = 'Expired' THEN 1 ELSE 0 END)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN dbo.VoucherStock_Table v
               ON v.ProviderId = p.Id
              AND (@Status IS NULL OR v.Status = @Status)
              AND (@From   IS NULL OR v.SaleDate >= @From)
              AND (@To     IS NULL OR v.SaleDate <= @To)
        WHERE (@Category IS NULL OR p.Category = @Category)
        GROUP BY p.Id, p.Name, p.Category, p.Status
        ORDER BY p.Name;
    END

    /* ---- Dropdown ---- */
    ELSE IF @Action = 'SelectDropdown'
    BEGIN
        SELECT Id, Name
        FROM dbo.VoucherProvider_Table
        WHERE Status = 'A'
        ORDER BY Name;
    END

    /* ---- Single row ---- */
    ELSE IF @Action = 'SelectId'
    BEGIN
        SELECT Id, Name, Category, ContactPerson, ContactEmail, ContactNo, Status
        FROM dbo.VoucherProvider_Table
        WHERE Id = @IdInt;
    END

    /* ---- Distinct category list (filter dropdown) ---- */
    ELSE IF @Action = 'SelectCategory'
    BEGIN
        SELECT DISTINCT Category
        FROM dbo.VoucherProvider_Table
        WHERE Category IS NOT NULL AND Category <> ''
        ORDER BY Category;
    END

    ELSE IF @Action = 'Insert'
    BEGIN
        INSERT INTO dbo.VoucherProvider_Table (Name, Category, Status)
        VALUES (@Name, @Category, ISNULL(@Status, 'A'));
        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END

    ELSE IF @Action = 'Update'
    BEGIN
        UPDATE dbo.VoucherProvider_Table
           SET Name = @Name,
               Category = @Category,
               Status = ISNULL(@Status, Status),
               ModifiedDate = GETDATE()
         WHERE Id = @IdInt;
    END
END
GO

PRINT 'Created dbo.Sp_VoucherProvider_Table';
GO
