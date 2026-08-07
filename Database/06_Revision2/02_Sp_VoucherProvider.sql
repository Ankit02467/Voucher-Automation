/* ============================================================
   Dashboard proc - revision 2.

   The grid now has ONE count column driven by the selected status:
     (blank) / All -> every voucher, whatever its status
     Used / Expired / Invalid -> that status
     Unused (+ @Days) -> unused vouchers lapsing within N days

   Early Expiry / To be Expired actions are gone - those buttons
   were removed from the screen.
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

    /* day window only applies to Unused */
    DECLARE @DayInt INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@Days)), ''));
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
                CASE
                    WHEN @Status IS NULL THEN 1
                    WHEN @Status = 'Unused' AND @WinEnd IS NOT NULL THEN
                        CASE WHEN v.Status = 'Unused'
                              AND v.ExpiryDate IS NOT NULL
                              AND v.ExpiryDate BETWEEN @Today AND @WinEnd
                             THEN 1 ELSE 0 END
                    ELSE CASE WHEN v.Status = @Status THEN 1 ELSE 0 END
                END),
            /* product names for the chevron drop-down, pipe separated */
            ProductNames = ISNULL((
                SELECT STRING_AGG(pr.Name, '|') WITHIN GROUP (ORDER BY pr.Name)
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

PRINT 'Dashboard proc updated';
GO
