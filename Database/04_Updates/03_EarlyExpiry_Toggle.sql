/* ============================================================
   Early Expiry toggle fix.

   Before: SelectEarlyExpiry INNER JOINed to unused+expiring vouchers,
           so the Used column changed too.
   After : LEFT JOIN keeps every provider and the FULL Used count;
           only the Unused column switches to the early-expiry (EE)
           number - unused vouchers expiring in the next 30 days.
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
    @ToDate   NVARCHAR(30)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdInt INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @From  DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@FromDate)), ''));
    DECLARE @To    DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ToDate)),   ''));
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @EEEnd DATE = DATEADD(DAY, 30, CAST(GETDATE() AS DATE));

    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), '');
    SET @Status   = NULLIF(LTRIM(RTRIM(@Status)),   '');

    /* ---- Normal provider summary ---- */
    IF @Action = 'SelectSummary'
    BEGIN
        SELECT
            p.Id,
            p.Name,
            p.Category,
            p.Status,
            TotalVoucher   = COUNT(v.Id),
            UsedVoucher    = SUM(CASE WHEN v.Status = 'Used'    THEN 1 ELSE 0 END),
            UnusedVoucher  = SUM(CASE WHEN v.Status = 'Unused'  THEN 1 ELSE 0 END),
            ExpiryVoucher  = SUM(CASE WHEN v.Status = 'Expiry'  THEN 1 ELSE 0 END),
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

    /* ---- Early Expiry view: same rows, same Used, Unused = EE only ---- */
    ELSE IF @Action = 'SelectEarlyExpiry'
    BEGIN
        SELECT
            p.Id,
            p.Name,
            p.Category,
            p.Status,
            TotalVoucher   = COUNT(v.Id),
            /* Used deliberately unfiltered - it must not change on toggle */
            UsedVoucher    = SUM(CASE WHEN v.Status = 'Used' THEN 1 ELSE 0 END),
            UnusedVoucher  = SUM(CASE WHEN v.Status = 'Unused'
                                       AND v.ExpiryDate IS NOT NULL
                                       AND v.ExpiryDate BETWEEN @Today AND @EEEnd
                                      THEN 1 ELSE 0 END),
            ExpiryVoucher  = SUM(CASE WHEN v.Status = 'Expiry'  THEN 1 ELSE 0 END),
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
    BEGIN
        SELECT Id, Name FROM dbo.VoucherProvider_Table WHERE Status = 'A' ORDER BY Id;
    END

    ELSE IF @Action = 'SelectCategory'
    BEGIN
        SELECT DISTINCT Category FROM dbo.VoucherProvider_Table
        WHERE Category IS NOT NULL AND Category <> '' ORDER BY Category;
    END

    ELSE IF @Action = 'SelectId'
    BEGIN
        SELECT Id, Name, Category, ContactPerson, ContactEmail, ContactNo, Status
        FROM dbo.VoucherProvider_Table WHERE Id = @IdInt;
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
           SET Name = @Name, Category = @Category,
               Status = ISNULL(@Status, Status), ModifiedDate = GETDATE()
         WHERE Id = @IdInt;
    END
END
GO

/* ------------------------------------------------------------
   Demo data only: the original seed put EVERY unused voucher
   inside the 30-day window, so the toggle showed identical
   numbers. Spread them out so the EE figure is a real subset.
   ------------------------------------------------------------ */
UPDATE dbo.VoucherStock_Table
   SET ExpiryDate = CASE WHEN Id % 4 = 0
                         THEN DATEADD(DAY, (Id % 28) + 1,  CAST(GETDATE() AS DATE))   -- inside EE window
                         ELSE DATEADD(DAY, (Id % 180) + 45, CAST(GETDATE() AS DATE))  -- outside
                    END
 WHERE Status = 'Unused';
GO

SELECT p.Name,
       Used     = SUM(CASE WHEN v.Status = 'Used'   THEN 1 ELSE 0 END),
       Unused   = SUM(CASE WHEN v.Status = 'Unused' THEN 1 ELSE 0 END),
       UnusedEE = SUM(CASE WHEN v.Status = 'Unused'
                            AND v.ExpiryDate BETWEEN CAST(GETDATE() AS DATE)
                                                 AND DATEADD(DAY,30,CAST(GETDATE() AS DATE))
                           THEN 1 ELSE 0 END)
FROM dbo.VoucherProvider_Table p
LEFT JOIN dbo.VoucherStock_Table v ON v.ProviderId = p.Id
GROUP BY p.Id, p.Name ORDER BY p.Id;
GO
