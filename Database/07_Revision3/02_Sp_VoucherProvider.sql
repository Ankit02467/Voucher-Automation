/* ============================================================
   Revision 3 - dashboard proc.

   Changes against 06_Revision2/02_Sp_VoucherProvider.sql:

   1. @Status = 'NotSet' counts vouchers whose Status IS NULL -
      a fresh upload nobody has triaged yet.

   2. The expiry window (@Days) is no longer tied to Unused. It is
      now its own "View Early Expiry" filter and combines with
      whatever status pill is active, so the number the dashboard
      shows always equals the number of rows View Data will list.

   3. ProductIds is returned alongside ProductNames, in the same
      order, so the dashboard can link each product name straight
      into View Data.

   4. Fixed: a provider with no vouchers at all used to report a
      count of 1. The LEFT JOIN produces one all-NULL row for such
      a provider and the old CASE counted it.
   ============================================================ */
USE DSL_New;
GO

CREATE OR ALTER PROCEDURE dbo.Sp_VoucherProvider_Table
(
    @Action   NVARCHAR(50),
    @Id       NVARCHAR(50)  = NULL,
    @Name     NVARCHAR(150) = NULL,
    @Category NVARCHAR(100) = NULL,
    @Status   NVARCHAR(20)  = NULL,
    @Days     NVARCHAR(10)  = NULL,
    @FromDate NVARCHAR(30)  = NULL,
    @ToDate   NVARCHAR(30)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdInt INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @From  DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@FromDate)), ''));
    DECLARE @To    DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ToDate)),   ''));
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), '');
    SET @Status   = NULLIF(LTRIM(RTRIM(@Status)),   '');
    IF @Status = 'All' SET @Status = NULL;

    /* early-expiry window; NULL means "no expiry restriction" */
    DECLARE @DayInt INT  = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@Days)), ''));
    DECLARE @WinEnd DATE = CASE WHEN @DayInt IS NULL THEN NULL
                                ELSE DATEADD(DAY, @DayInt, @Today) END;

    IF @Action = 'SelectSummary'
    BEGIN
        SELECT
            p.Id,
            p.Name,
            p.Category,
            p.Status,
            /* the single figure shown under the status-named column */
            StatusCount = SUM(
                CASE WHEN v.Id IS NOT NULL
                      AND (@Status IS NULL
                           OR (@Status =  'NotSet' AND v.Status IS NULL)
                           OR (@Status <> 'NotSet' AND v.Status = @Status))
                      AND (@WinEnd IS NULL
                           OR (v.ExpiryDate IS NOT NULL
                               AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                     THEN 1 ELSE 0 END),
            /* names and ids share one ORDER BY, so index N matches index N */
            ProductNames = ISNULL((
                SELECT STRING_AGG(pr.Name, '|') WITHIN GROUP (ORDER BY pr.Name)
                FROM dbo.VoucherProduct_Table pr
                WHERE pr.ProviderId = p.Id AND pr.Status = 'A'), ''),
            ProductIds = ISNULL((
                SELECT STRING_AGG(CONVERT(VARCHAR(20), pr.Id), '|') WITHIN GROUP (ORDER BY pr.Name)
                FROM dbo.VoucherProduct_Table pr
                WHERE pr.ProviderId = p.Id AND pr.Status = 'A'), ''),
            ProductCount = (SELECT COUNT(*) FROM dbo.VoucherProduct_Table pr
                            WHERE pr.ProviderId = p.Id AND pr.Status = 'A')
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN dbo.VoucherStock_Table v
               ON v.ProviderId = p.Id
              AND (@From IS NULL OR v.SaleDate >= @From)
              AND (@To   IS NULL OR v.SaleDate <= @To)
        WHERE (@Category IS NULL OR p.Category = @Category)
        GROUP BY p.Id, p.Name, p.Category, p.Status
        ORDER BY p.Id;
    END

    ELSE IF @Action = 'SelectDropdown'
        SELECT Id, Name FROM dbo.VoucherProvider_Table WHERE Status = 'A' ORDER BY Id;

    ELSE IF @Action = 'SelectCategory'
        SELECT DISTINCT Category FROM dbo.VoucherProvider_Table
        WHERE Category IS NOT NULL AND Category <> '' ORDER BY Category;

    ELSE IF @Action = 'SelectId'
        SELECT Id, Name, Category, ContactPerson, ContactEmail, ContactNo, Status
        FROM dbo.VoucherProvider_Table WHERE Id = @IdInt;

    ELSE IF @Action = 'Insert'
    BEGIN
        INSERT INTO dbo.VoucherProvider_Table (Name, Category, Status)
        VALUES (@Name, @Category, ISNULL(@Status, 'A'));
        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END

    ELSE IF @Action = 'Update'
        UPDATE dbo.VoucherProvider_Table
           SET Name = @Name, Category = @Category,
               Status = ISNULL(@Status, Status), ModifiedDate = GETDATE()
         WHERE Id = @IdInt;
END
GO

PRINT 'Sp_VoucherProvider_Table updated (Not Set status, early-expiry window, ProductIds)';
GO
