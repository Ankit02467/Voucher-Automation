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

   5. @Status = 'UnusedOrNotSet' takes Unused and untriaged
      (Status IS NULL) together. It is what "View Early Expiry"
      asks for: a voucher already used, expired or written off has
      nothing to chase, so counting it as expiring is noise. The
      "Expiring soon" card is narrowed the same way, and the two
      have to agree because the card opens that view.
   ============================================================ */
USE DSL_New;
GO

CREATE OR ALTER PROCEDURE dbo.Sp_VoucherProvider_Table
(
    @Action   NVARCHAR(50),
    @Id       NVARCHAR(50)  = NULL,
    @Name     NVARCHAR(150) = NULL,
    @Category NVARCHAR(100) = NULL,
    @Status     NVARCHAR(20)  = NULL,
    @Days       NVARCHAR(10)  = NULL,
    @FromDate   NVARCHAR(30)  = NULL,
    @ToDate     NVARCHAR(30)  = NULL,
    /* Same two the grid on View Data uses. Without them the dashboard counted
       every voucher while View Data showed only the ones that role can see - a
       sub-admin read 24 against AWS and landed on 19 rows, because the other
       five had already moved to the done list. */
    @AssignedTo NVARCHAR(50)  = NULL,
    @IsMoved    NVARCHAR(5)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AssignInt INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@AssignedTo)), ''));
    DECLARE @MovedBit  INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@IsMoved)), ''));

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
        /* Product list under each provider, counted against whatever status and
           expiry window are in force.

           With a status picked, a product holding none of it is dropped: opening
           a provider under "Unused" to be shown products with nothing unused is
           noise. With no status (All), every active product stays, because there
           the list is describing the catalogue rather than a result set. */
        ;WITH ProductRow AS
        (
            SELECT pr.Id, pr.ProviderId, pr.Name,
                   Cnt = COUNT(v.Id)
            FROM dbo.VoucherProduct_Table pr
            LEFT JOIN dbo.VoucherStock_Table v
                   ON v.ProductId = pr.Id
                  AND (@Status IS NULL
                       OR (@Status = 'NotSet'         AND v.Status IS NULL)
                       OR (@Status = 'UnusedOrNotSet' AND (v.Status IS NULL OR v.Status = 'Unused'))
                       OR (@Status NOT IN ('NotSet', 'UnusedOrNotSet') AND v.Status = @Status))
                  AND (@WinEnd IS NULL
                       OR (v.ExpiryDate IS NOT NULL
                           AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                  AND (@AssignInt IS NULL OR v.AssignedTo = @AssignInt)
                  AND (@MovedBit  IS NULL OR v.IsMoved    = @MovedBit)
            WHERE pr.Status = 'A'
            GROUP BY pr.Id, pr.ProviderId, pr.Name
        ),
        Shown AS
        (
            SELECT * FROM ProductRow
            WHERE (@Status IS NULL AND @WinEnd IS NULL) OR Cnt > 0
        )
        SELECT
            p.Id,
            p.Name,
            p.Category,
            p.Status,
            /* the single figure shown under the status-named column */
            StatusCount = SUM(
                CASE WHEN v.Id IS NOT NULL
                      AND (@Status IS NULL
                           OR (@Status = 'NotSet'         AND v.Status IS NULL)
                           OR (@Status = 'UnusedOrNotSet' AND (v.Status IS NULL OR v.Status = 'Unused'))
                           OR (@Status NOT IN ('NotSet', 'UnusedOrNotSet') AND v.Status = @Status))
                      AND (@WinEnd IS NULL
                           OR (v.ExpiryDate IS NOT NULL
                               AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                     THEN 1 ELSE 0 END),
            /* names, ids and counts share one ORDER BY, so index N of each
               lines up with index N of the others */
            ProductNames = ISNULL((
                SELECT STRING_AGG(s.Name, '|') WITHIN GROUP (ORDER BY s.Name)
                FROM Shown s WHERE s.ProviderId = p.Id), ''),
            ProductIds = ISNULL((
                SELECT STRING_AGG(CONVERT(VARCHAR(20), s.Id), '|') WITHIN GROUP (ORDER BY s.Name)
                FROM Shown s WHERE s.ProviderId = p.Id), ''),
            ProductCounts = ISNULL((
                SELECT STRING_AGG(CONVERT(VARCHAR(20), s.Cnt), '|') WITHIN GROUP (ORDER BY s.Name)
                FROM Shown s WHERE s.ProviderId = p.Id), ''),
            /* the number beside the provider name must agree with what opens */
            ProductCount = (SELECT COUNT(*) FROM Shown s WHERE s.ProviderId = p.Id),

            /* Full status split for the distribution bar. Deliberately NOT
               narrowed by the status pill - the bar is what shows the split, so
               filtering it to one status would leave a single solid block. It
               does follow the expiry window, so the bar describes the same
               vouchers the rest of the row is counting. */
            TotalCount = SUM(CASE WHEN v.Id IS NOT NULL
                                   AND (@WinEnd IS NULL OR (v.ExpiryDate IS NOT NULL
                                        AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                                  THEN 1 ELSE 0 END),
            UsedCount = SUM(CASE WHEN v.Status = 'Used'
                                  AND (@WinEnd IS NULL OR (v.ExpiryDate IS NOT NULL
                                       AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                                 THEN 1 ELSE 0 END),
            UnusedCount = SUM(CASE WHEN v.Status = 'Unused'
                                    AND (@WinEnd IS NULL OR (v.ExpiryDate IS NOT NULL
                                         AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                                   THEN 1 ELSE 0 END),
            ExpiredCount = SUM(CASE WHEN v.Status = 'Expired'
                                     AND (@WinEnd IS NULL OR (v.ExpiryDate IS NOT NULL
                                          AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                                    THEN 1 ELSE 0 END),
            InvalidCount = SUM(CASE WHEN v.Status = 'Invalid'
                                     AND (@WinEnd IS NULL OR (v.ExpiryDate IS NOT NULL
                                          AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                                    THEN 1 ELSE 0 END),
            NotSetCount = SUM(CASE WHEN v.Id IS NOT NULL AND v.Status IS NULL
                                    AND (@WinEnd IS NULL OR (v.ExpiryDate IS NOT NULL
                                         AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
                                   THEN 1 ELSE 0 END)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN dbo.VoucherStock_Table v
               ON v.ProviderId = p.Id
              AND (@From IS NULL OR v.SaleDate >= @From)
              AND (@To   IS NULL OR v.SaleDate <= @To)
              /* every count below inherits these, so the figure in the row and
                 the bar beside it describe the same vouchers View Data will list */
              AND (@AssignInt IS NULL OR v.AssignedTo = @AssignInt)
              AND (@MovedBit  IS NULL OR v.IsMoved    = @MovedBit)
        WHERE (@Category IS NULL OR p.Category = @Category)
        GROUP BY p.Id, p.Name, p.Category, p.Status
        ORDER BY p.Id;
    END

    /* ---------- the figures across the top of the dashboard ---------- */
    ELSE IF @Action = 'SelectDashboardTotals'
    BEGIN
        DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

        SELECT
            TotalVoucher = COUNT(*),
            /* ISNULL on every SUM: with no rows at all a SUM returns NULL while
               COUNT(*) returns 0, so a database whose stock table is still empty
               hands the page DBNull cards and Convert.ToInt32 throws on them. */
            Used     = ISNULL(SUM(CASE WHEN Status = 'Used'    THEN 1 ELSE 0 END), 0),
            Unused   = ISNULL(SUM(CASE WHEN Status = 'Unused'  THEN 1 ELSE 0 END), 0),
            Expired  = ISNULL(SUM(CASE WHEN Status = 'Expired' THEN 1 ELSE 0 END), 0),
            Invalid  = ISNULL(SUM(CASE WHEN Status = 'Invalid' THEN 1 ELSE 0 END), 0),
            NotSet   = ISNULL(SUM(CASE WHEN Status IS NULL     THEN 1 ELSE 0 END), 0),
            /* The "expiring soon" card - a 30 day window from today, counting
               only what is still worth chasing: Unused, and untriaged uploads
               nobody has looked at yet. A voucher already used, expired or
               written off is going nowhere, and counting it here sent people to
               a list they could do nothing with. The card opens the same
               Unused / Not Set view, so the two figures agree. */
            ExpiringSoon = ISNULL(SUM(CASE WHEN (Status IS NULL OR Status = 'Unused')
                                        AND ExpiryDate BETWEEN @Today AND DATEADD(DAY, 30, @Today)
                                    THEN 1 ELSE 0 END), 0),
            /* stock as it stood at the start of this month, so the page can say
               how far it has moved since. Read off AddedDate - there is no daily
               snapshot anywhere, so this measures stock added, not stock held. */
            BeforeThisMonth = ISNULL(SUM(CASE WHEN AddedDate < @MonthStart THEN 1 ELSE 0 END), 0),
            Providers = (SELECT COUNT(*) FROM dbo.VoucherProvider_Table cp
                          WHERE @Category IS NULL OR cp.Category = @Category),
            Products  = (SELECT COUNT(*) FROM dbo.VoucherProduct_Table pr
                          JOIN dbo.VoucherProvider_Table cp ON cp.Id = pr.ProviderId
                         WHERE pr.Status = 'A'
                           AND (@Category IS NULL OR cp.Category = @Category))
        FROM dbo.VoucherStock_Table s
        /* scoped the same way as the grid below them - cards reading 128 above a
           table whose rows add up to less is the same mismatch, one level up */
        WHERE (@AssignInt IS NULL OR s.AssignedTo = @AssignInt)
          AND (@MovedBit  IS NULL OR s.IsMoved    = @MovedBit)
          /* The sidebar's category narrows these cards the same way it already
             narrows the provider table underneath. Without it, picking IT or
             Language left every figure still reading the whole stock, so All,
             IT and Language all showed the same numbers. */
          AND (@Category IS NULL OR EXISTS (
                  SELECT 1 FROM dbo.VoucherProvider_Table cp
                   WHERE cp.Id = s.ProviderId AND cp.Category = @Category));
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
        /* UQ_VoucherProvider_Name would raise here, and an unhandled 2627 on a
           form is a yellow screen rather than an answer. -1 back instead, the
           same way Sp_VoucherProduct_Table reports a duplicate. */
        IF EXISTS (SELECT 1 FROM dbo.VoucherProvider_Table WHERE Name = @Name)
        BEGIN SELECT -1; RETURN; END

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
