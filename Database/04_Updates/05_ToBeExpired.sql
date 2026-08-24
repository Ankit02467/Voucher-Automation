/* ============================================================
   "To be Expired" view.

   Shows how many UNUSED vouchers lapse within the next N days,
   where N is 1 / 3 / 5 / 7 (1 week), chosen from the screen.

   Same rule as Early Expiry: the Used column is never filtered -
   only the Unused column switches to the countdown figure.
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
    @FromDate NVARCHAR(30)  = NULL,
    @ToDate   NVARCHAR(30)  = NULL,
    @Days     NVARCHAR(10)  = NULL   -- To be Expired window
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdInt INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @From  DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@FromDate)), ''));
    DECLARE @To    DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ToDate)),   ''));
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @EEEnd DATE = DATEADD(DAY, 30, CAST(GETDATE() AS DATE));

    /* window for To be Expired - defaults to 1 day, capped at 7 */
    DECLARE @DayInt INT = ISNULL(TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@Days)), '')), 1);
    IF @DayInt < 1 SET @DayInt = 1;
    IF @DayInt > 7 SET @DayInt = 7;
    DECLARE @TbeEnd DATE = DATEADD(DAY, @DayInt, @Today);

    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), '');
    SET @Status   = NULLIF(LTRIM(RTRIM(@Status)),   '');

    IF @Action = 'SelectSummary'
    BEGIN
        SELECT
            p.Id, p.Name, p.Category, p.Status,
            TotalVoucher   = COUNT(v.Id),
            UsedVoucher    = SUM(CASE WHEN v.Status = 'Used'    THEN 1 ELSE 0 END),
            UnusedVoucher  = SUM(CASE WHEN v.Status = 'Unused'  THEN 1 ELSE 0 END),
            ExpiredVoucher = SUM(CASE WHEN v.Status = 'Expired' THEN 1 ELSE 0 END),
            InvalidVoucher = SUM(CASE WHEN v.Status = 'Invalid' THEN 1 ELSE 0 END)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN dbo.VoucherStock_Table v
               ON v.ProviderId = p.Id
              AND (@From IS NULL OR v.SaleDate >= @From)
              AND (@To   IS NULL OR v.SaleDate <= @To)
        WHERE (@Category IS NULL OR p.Category = @Category)
          AND (@Status IS NULL OR EXISTS (
                  SELECT 1 FROM dbo.VoucherStock_Table s
                  WHERE s.ProviderId = p.Id AND s.Status = @Status))
        GROUP BY p.Id, p.Name, p.Category, p.Status
        ORDER BY p.Id;
    END

    /* Unused vouchers lapsing in the next 30 days */
    ELSE IF @Action = 'SelectEarlyExpiry'
    BEGIN
        SELECT
            p.Id, p.Name, p.Category, p.Status,
            TotalVoucher   = COUNT(v.Id),
            UsedVoucher    = SUM(CASE WHEN v.Status = 'Used' THEN 1 ELSE 0 END),
            UnusedVoucher  = SUM(CASE WHEN v.Status = 'Unused'
                                       AND v.ExpiryDate IS NOT NULL
                                       AND v.ExpiryDate BETWEEN @Today AND @EEEnd
                                      THEN 1 ELSE 0 END),
            ExpiredVoucher = SUM(CASE WHEN v.Status = 'Expired' THEN 1 ELSE 0 END),
            InvalidVoucher = SUM(CASE WHEN v.Status = 'Invalid' THEN 1 ELSE 0 END)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN dbo.VoucherStock_Table v
               ON v.ProviderId = p.Id
              AND (@From IS NULL OR v.SaleDate >= @From)
              AND (@To   IS NULL OR v.SaleDate <= @To)
        WHERE (@Category IS NULL OR p.Category = @Category)
          AND (@Status IS NULL OR EXISTS (
                  SELECT 1 FROM dbo.VoucherStock_Table s
                  WHERE s.ProviderId = p.Id AND s.Status = @Status))
        GROUP BY p.Id, p.Name, p.Category, p.Status
        ORDER BY p.Id;
    END

    /* Unused vouchers lapsing in the next @Days days (1 / 3 / 5 / 7) */
    ELSE IF @Action = 'SelectToBeExpired'
    BEGIN
        SELECT
            p.Id, p.Name, p.Category, p.Status,
            TotalVoucher   = COUNT(v.Id),
            UsedVoucher    = SUM(CASE WHEN v.Status = 'Used' THEN 1 ELSE 0 END),
            UnusedVoucher  = SUM(CASE WHEN v.Status = 'Unused'
                                       AND v.ExpiryDate IS NOT NULL
                                       AND v.ExpiryDate BETWEEN @Today AND @TbeEnd
                                      THEN 1 ELSE 0 END),
            ExpiredVoucher = SUM(CASE WHEN v.Status = 'Expired' THEN 1 ELSE 0 END),
            InvalidVoucher = SUM(CASE WHEN v.Status = 'Invalid' THEN 1 ELSE 0 END)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN dbo.VoucherStock_Table v
               ON v.ProviderId = p.Id
              AND (@From IS NULL OR v.SaleDate >= @From)
              AND (@To   IS NULL OR v.SaleDate <= @To)
        WHERE (@Category IS NULL OR p.Category = @Category)
          AND (@Status IS NULL OR EXISTS (
                  SELECT 1 FROM dbo.VoucherStock_Table s
                  WHERE s.ProviderId = p.Id AND s.Status = @Status))
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

/* ------------------------------------------------------------
   Demo data only: give the unused vouchers a spread of expiry
   dates inside the next week so 1 / 3 / 5 / 7 day windows differ.
   ------------------------------------------------------------ */
UPDATE dbo.VoucherStock_Table
   SET ExpiryDate = CASE (Id % 10)
                        WHEN 0 THEN DATEADD(DAY, 1,  CAST(GETDATE() AS DATE))
                        WHEN 1 THEN DATEADD(DAY, 3,  CAST(GETDATE() AS DATE))
                        WHEN 2 THEN DATEADD(DAY, 5,  CAST(GETDATE() AS DATE))
                        WHEN 3 THEN DATEADD(DAY, 7,  CAST(GETDATE() AS DATE))
                        WHEN 4 THEN DATEADD(DAY, 20, CAST(GETDATE() AS DATE))
                        ELSE        DATEADD(DAY, (Id % 180) + 45, CAST(GETDATE() AS DATE))
                    END
 WHERE Status = 'Unused';
GO

SELECT p.Name,
       Used    = SUM(CASE WHEN v.Status='Used'   THEN 1 ELSE 0 END),
       Unused  = SUM(CASE WHEN v.Status='Unused' THEN 1 ELSE 0 END),
       [1Day]  = SUM(CASE WHEN v.Status='Unused' AND v.ExpiryDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY,1,CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END),
       [3Day]  = SUM(CASE WHEN v.Status='Unused' AND v.ExpiryDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY,3,CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END),
       [5Day]  = SUM(CASE WHEN v.Status='Unused' AND v.ExpiryDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY,5,CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END),
       [1Week] = SUM(CASE WHEN v.Status='Unused' AND v.ExpiryDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY,7,CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END),
       [EE30]  = SUM(CASE WHEN v.Status='Unused' AND v.ExpiryDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY,30,CAST(GETDATE() AS DATE)) THEN 1 ELSE 0 END)
FROM dbo.VoucherProvider_Table p
LEFT JOIN dbo.VoucherStock_Table v ON v.ProviderId = p.Id
GROUP BY p.Id, p.Name ORDER BY p.Id;
GO
