/* ============================================================
   Revision 3 - performance counters.

   "How many vouchers has this student checked" is answered from
   VoucherHistory_Table, not VoucherStock_Table: the stock row only
   remembers the LAST check, while history carries one row per
   check event with who did it and when.

   A check means Activity IN ('Status Update', 'Voucher Checked').
   Assignments and moves are not checks and are not counted.

   COUNT(DISTINCT VoucherId) - checking the same voucher twice in a
   day is one voucher checked, not two.

   Windows are rolling and inclusive of today:
       Today   = today
       Weekly  = the last 7 days
       Monthly = the last 30 days
   They do not reset on a Monday or on the 1st of the month.

   Four actions:
       SelectByProvider - one student, split by provider
                          (the student's own dashboard)
       SelectByStudent  - all students, optionally narrowed to one
                          provider (admin / sub-admin screen)

       SelectProviderChecks - every provider, counting checks by
                          anyone. Product-wise performance, top level.
       SelectProductChecks  - the same, split by product within one
                          provider. What the row expands into.

   The two Checks actions ignore who did the checking - they answer
   "how much of this provider's stock was worked on", not "by whom".
   ============================================================ */
USE DSL_New;
GO

CREATE OR ALTER PROCEDURE dbo.Sp_VoucherPerformance_Table
(
    @Action     NVARCHAR(50),
    @UserId     NVARCHAR(50) = NULL,
    @ProviderId NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserInt     INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@UserId)), ''));
    DECLARE @ProviderInt INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@ProviderId)), ''));

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @Week  DATE = DATEADD(DAY, -6,  @Today);   -- 7 days counting today
    DECLARE @Month DATE = DATEADD(DAY, -29, @Today);   -- 30 days counting today

    /* ---------- one student, split by provider ---------- */
    IF @Action = 'SelectByProvider'
        SELECT p.Id,
               ProviderName = p.Name,
               Today   = ISNULL(x.Today,   0),
               Weekly  = ISNULL(x.Weekly,  0),
               Monthly = ISNULL(x.Monthly, 0)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN
        (
            SELECT v.ProviderId,
                   Today   = COUNT(DISTINCT CASE WHEN h.ChangedDate >= @Today THEN h.VoucherId END),
                   Weekly  = COUNT(DISTINCT CASE WHEN h.ChangedDate >= @Week  THEN h.VoucherId END),
                   Monthly = COUNT(DISTINCT h.VoucherId)
            FROM dbo.VoucherHistory_Table h
            INNER JOIN dbo.VoucherStock_Table v ON v.Id = h.VoucherId
            WHERE h.ChangedBy = @UserInt
              AND h.Activity IN ('Status Update', 'Voucher Checked')
              AND h.ChangedDate >= @Month
            GROUP BY v.ProviderId
        ) x ON x.ProviderId = p.Id
        ORDER BY p.Id;

    /* ---------- all students, optionally one provider ---------- */
    ELSE IF @Action = 'SelectByStudent'
        SELECT u.Id,
               StudentName = u.FullName,
               Today   = ISNULL(x.Today,   0),
               Weekly  = ISNULL(x.Weekly,  0),
               Monthly = ISNULL(x.Monthly, 0)
        FROM dbo.User_Table u
        INNER JOIN dbo.UserTypeMaster t ON t.Id = u.[Type]
        LEFT JOIN
        (
            SELECT h.ChangedBy,
                   Today   = COUNT(DISTINCT CASE WHEN h.ChangedDate >= @Today THEN h.VoucherId END),
                   Weekly  = COUNT(DISTINCT CASE WHEN h.ChangedDate >= @Week  THEN h.VoucherId END),
                   Monthly = COUNT(DISTINCT h.VoucherId)
            FROM dbo.VoucherHistory_Table h
            INNER JOIN dbo.VoucherStock_Table v ON v.Id = h.VoucherId
            WHERE h.Activity IN ('Status Update', 'Voucher Checked')
              AND h.ChangedDate >= @Month
              AND (@ProviderInt IS NULL OR v.ProviderId = @ProviderInt)
            GROUP BY h.ChangedBy
        ) x ON x.ChangedBy = u.Id
        WHERE t.TypeId = 4
          AND t.UserTypeName = 'Voucher Student'
          AND u.Status = 1
        ORDER BY u.FullName;

    /* ---------- every provider, checks by anyone ---------- */
    ELSE IF @Action = 'SelectProviderChecks'
        SELECT p.Id,
               ProviderName = p.Name,
               ProductCount = (SELECT COUNT(*) FROM dbo.VoucherProduct_Table pr
                               WHERE pr.ProviderId = p.Id AND pr.Status = 'A'),
               Today   = ISNULL(x.Today,   0),
               Weekly  = ISNULL(x.Weekly,  0),
               Monthly = ISNULL(x.Monthly, 0)
        FROM dbo.VoucherProvider_Table p
        LEFT JOIN
        (
            SELECT v.ProviderId,
                   Today   = COUNT(DISTINCT CASE WHEN h.ChangedDate >= @Today THEN h.VoucherId END),
                   Weekly  = COUNT(DISTINCT CASE WHEN h.ChangedDate >= @Week  THEN h.VoucherId END),
                   Monthly = COUNT(DISTINCT h.VoucherId)
            FROM dbo.VoucherHistory_Table h
            INNER JOIN dbo.VoucherStock_Table v ON v.Id = h.VoucherId
            WHERE h.Activity IN ('Status Update', 'Voucher Checked')
              AND h.ChangedDate >= @Month
            GROUP BY v.ProviderId
        ) x ON x.ProviderId = p.Id
        ORDER BY p.Id;

    /* ---------- the same, per product inside one provider ---------- */
    ELSE IF @Action = 'SelectProductChecks'
        SELECT pr.Id,
               ProductName = pr.Name,
               Today   = ISNULL(x.Today,   0),
               Weekly  = ISNULL(x.Weekly,  0),
               Monthly = ISNULL(x.Monthly, 0)
        FROM dbo.VoucherProduct_Table pr
        LEFT JOIN
        (
            SELECT v.ProductId,
                   Today   = COUNT(DISTINCT CASE WHEN h.ChangedDate >= @Today THEN h.VoucherId END),
                   Weekly  = COUNT(DISTINCT CASE WHEN h.ChangedDate >= @Week  THEN h.VoucherId END),
                   Monthly = COUNT(DISTINCT h.VoucherId)
            FROM dbo.VoucherHistory_Table h
            INNER JOIN dbo.VoucherStock_Table v ON v.Id = h.VoucherId
            WHERE h.Activity IN ('Status Update', 'Voucher Checked')
              AND h.ChangedDate >= @Month
            GROUP BY v.ProductId
        ) x ON x.ProductId = pr.Id
        WHERE pr.Status = 'A'
          AND (@ProviderInt IS NULL OR pr.ProviderId = @ProviderInt)
        ORDER BY pr.Name;
END
GO

PRINT 'Sp_VoucherPerformance_Table created';
GO
