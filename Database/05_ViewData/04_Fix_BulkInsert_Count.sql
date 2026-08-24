/* ============================================================
   Fix: BulkInsert reported "0 inserted" even when rows went in.

   1. DECLARE @Ins INT = @@ROWCOUNT resets @@ROWCOUNT before the
      assignment, so the count was always 0. Capture it with a
      separate SET immediately after the INSERT.
   2. The in-batch duplicate guard was a no-op
      (HAVING COUNT(*) > 1 AND MIN(Code) IS NULL is never true).
      De-duplicate the parsed rows properly instead.

   Only the BulkInsert branch changed; the proc is re-emitted in
   full because T-SQL has no way to alter a single branch.
   ============================================================ */
USE DSL_New;
GO

CREATE OR ALTER PROCEDURE dbo.Sp_VoucherStock_Table
(
    @Action           NVARCHAR(50),
    @Id               NVARCHAR(50)   = NULL,
    @ProviderId       NVARCHAR(50)   = NULL,
    @ProductId        NVARCHAR(50)   = NULL,
    @VoucherCode      NVARCHAR(100)  = NULL,
    @ExpiryDate       NVARCHAR(30)   = NULL,
    @DealerName       NVARCHAR(150)  = NULL,
    @SaleDate         NVARCHAR(30)   = NULL,
    @DealerName2      NVARCHAR(150)  = NULL,
    @SaleDate2        NVARCHAR(30)   = NULL,
    @Status           NVARCHAR(20)   = NULL,
    @VoucherCheckDate NVARCHAR(30)   = NULL,
    @CheckedBy        NVARCHAR(100)  = NULL,
    @UsedDate         NVARCHAR(30)   = NULL,
    @CandidateName    NVARCHAR(150)  = NULL,
    @ExamDate         NVARCHAR(30)   = NULL,
    @ExamMode         NVARCHAR(50)   = NULL,
    @AssignedTo       NVARCHAR(50)   = NULL,
    @Ids              NVARCHAR(MAX)  = NULL,
    @Data             NVARCHAR(MAX)  = NULL,
    @AddedBy          NVARCHAR(50)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdInt       INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @ProviderInt INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@ProviderId)), ''));
    DECLARE @ProductInt  INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@ProductId)), ''));
    DECLARE @UserInt     INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@AddedBy)), ''));
    DECLARE @AssignInt   INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@AssignedTo)), ''));
    DECLARE @Expiry      DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ExpiryDate)), ''));
    DECLARE @Sale        DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@SaleDate)), ''));
    DECLARE @Sale2       DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@SaleDate2)), ''));
    DECLARE @Used        DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@UsedDate)), ''));
    DECLARE @Exam        DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ExamDate)), ''));
    DECLARE @CheckDt     DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@VoucherCheckDate)), ''));
    DECLARE @Ins         INT  = 0;
    DECLARE @Total       INT  = 0;
    DECLARE @Old         NVARCHAR(20);

    SET @VoucherCode   = NULLIF(LTRIM(RTRIM(@VoucherCode)), '');
    SET @DealerName    = NULLIF(LTRIM(RTRIM(@DealerName)),  '');
    SET @DealerName2   = NULLIF(LTRIM(RTRIM(@DealerName2)), '');
    SET @CheckedBy     = NULLIF(LTRIM(RTRIM(@CheckedBy)),   '');
    SET @Status        = NULLIF(LTRIM(RTRIM(@Status)),      '');
    SET @CandidateName = NULLIF(LTRIM(RTRIM(@CandidateName)), '');
    SET @ExamMode      = NULLIF(LTRIM(RTRIM(@ExamMode)),    '');

    IF @Action IN ('Select', 'SelectAll', 'SelectFilter', 'SelectExport')
        SELECT
            v.Id, v.ProviderId, ProviderName = p.Name, v.ProductId, ProductName = pr.Name,
            v.VoucherCode, v.ExpiryDate, AddedByName = ISNULL(u.FullName, ''),
            v.DealerName, v.SaleDate, v.DealerName2, v.SaleDate2,
            v.Status, v.UsedDate, v.VoucherCheckDate, v.CheckedBy,
            v.CandidateName, v.ExamDate, v.ExamMode,
            v.AssignedTo, AssignedToName = ISNULL(a.FullName, ''),
            v.Remarks, v.AddedDate
        FROM dbo.VoucherStock_Table v
        INNER JOIN dbo.VoucherProvider_Table p  ON p.Id  = v.ProviderId
        INNER JOIN dbo.VoucherProduct_Table  pr ON pr.Id = v.ProductId
        LEFT  JOIN dbo.User_Table u ON u.Id = v.AddedBy
        LEFT  JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE (@ProviderInt IS NULL OR v.ProviderId  = @ProviderInt)
          AND (@ProductInt  IS NULL OR v.ProductId   = @ProductInt)
          AND (@VoucherCode IS NULL OR v.VoucherCode LIKE '%' + @VoucherCode + '%')
          AND (@DealerName  IS NULL OR v.DealerName  LIKE '%' + @DealerName  + '%'
                                    OR v.DealerName2 LIKE '%' + @DealerName  + '%')
          AND (@CheckedBy   IS NULL OR v.CheckedBy   = @CheckedBy)
          AND (@Status      IS NULL OR v.Status      = @Status)
          AND (@CheckDt     IS NULL OR CAST(v.VoucherCheckDate AS DATE) = @CheckDt)
          AND (@AssignInt   IS NULL OR v.AssignedTo  = @AssignInt)
        ORDER BY v.Id DESC;

    ELSE IF @Action = 'SelectId'
        SELECT Id, ProviderId, ProductId, VoucherCode, ExpiryDate, DealerName, SaleDate,
               DealerName2, SaleDate2, Status, UsedDate, VoucherCheckDate, CheckedBy,
               CandidateName, ExamDate, ExamMode, AssignedTo, Remarks
        FROM dbo.VoucherStock_Table WHERE Id = @IdInt;

    ELSE IF @Action = 'SelectCheckedBy'
        SELECT DISTINCT CheckedBy FROM dbo.VoucherStock_Table
        WHERE CheckedBy IS NOT NULL AND CheckedBy <> '' ORDER BY CheckedBy;

    ELSE IF @Action = 'SelectCount'
        SELECT TotalVoucher   = COUNT(*),
               UsedVoucher    = SUM(CASE WHEN Status = 'Used'    THEN 1 ELSE 0 END),
               UnusedVoucher  = SUM(CASE WHEN Status = 'Unused'  THEN 1 ELSE 0 END),
               ExpiredVoucher = SUM(CASE WHEN Status = 'Expired' THEN 1 ELSE 0 END),
               InvalidVoucher = SUM(CASE WHEN Status = 'Invalid' THEN 1 ELSE 0 END),
               CheckedVoucher = SUM(CASE WHEN VoucherCheckDate IS NOT NULL THEN 1 ELSE 0 END)
        FROM dbo.VoucherStock_Table
        WHERE (@ProviderInt IS NULL OR ProviderId = @ProviderInt);

    /* ================= upload entry (paste from Excel) ================= */
    ELSE IF @Action = 'BulkInsert'
    BEGIN
        IF @ProductInt IS NULL OR @Data IS NULL
        BEGIN
            SELECT Inserted = 0, Skipped = 0;
            RETURN;
        END

        DECLARE @Rows TABLE (Code NVARCHAR(100) PRIMARY KEY, Expiry DATE);

        /* one row per distinct pasted code */
        INSERT INTO @Rows (Code, Expiry)
        SELECT Code, MIN(Expiry)
        FROM (
            SELECT Code   = LTRIM(RTRIM(LEFT(s.value, CHARINDEX('|', s.value + '|') - 1))),
                   Expiry = TRY_CONVERT(DATE, LTRIM(RTRIM(
                                SUBSTRING(s.value, CHARINDEX('|', s.value + '|') + 1, 4000))))
            FROM STRING_SPLIT(@Data, '~') s
            WHERE LTRIM(RTRIM(s.value)) <> ''
        ) parsed
        WHERE Code <> ''
        GROUP BY Code;

        SET @Total = (SELECT COUNT(*) FROM @Rows);

        INSERT INTO dbo.VoucherStock_Table
            (ProviderId, ProductId, VoucherCode, ExpiryDate, Status, AddedBy)
        SELECT pr.ProviderId, @ProductInt, r.Code, r.Expiry, 'Unused', @UserInt
        FROM @Rows r
        CROSS APPLY (SELECT ProviderId FROM dbo.VoucherProduct_Table WHERE Id = @ProductInt) pr
        WHERE NOT EXISTS (SELECT 1 FROM dbo.VoucherStock_Table v WHERE v.VoucherCode = r.Code);

        SET @Ins = @@ROWCOUNT;      -- captured straight after the INSERT

        SELECT Inserted = @Ins, Skipped = @Total - @Ins;
    END

    ELSE IF @Action = 'UpdateDealer'
    BEGIN
        UPDATE dbo.VoucherStock_Table
           SET DealerName = @DealerName, SaleDate = @Sale,
               DealerName2 = @DealerName2, SaleDate2 = @Sale2,
               ModifiedBy = @UserInt, ModifiedDate = GETDATE()
         WHERE Id = @IdInt;
        SELECT @IdInt;
    END

    ELSE IF @Action = 'UpdateStatusEntry'
    BEGIN
        SET @Old = (SELECT Status FROM dbo.VoucherStock_Table WHERE Id = @IdInt);

        UPDATE dbo.VoucherStock_Table
           SET Status           = ISNULL(@Status, Status),
               UsedDate         = CASE WHEN @Status = 'Used' THEN @Used ELSE NULL END,
               CandidateName    = @CandidateName,
               ExamDate         = @Exam,
               ExamMode         = @ExamMode,
               VoucherCheckDate = GETDATE(),
               CheckedBy        = @CheckedBy,
               ModifiedBy       = @UserInt,
               ModifiedDate     = GETDATE()
         WHERE Id = @IdInt;

        INSERT INTO dbo.VoucherHistory_Table
            (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy, VoucherCheckDate, ChangedBy)
        SELECT Id, ProductId, VoucherCode, @Old, Status, CheckedBy, VoucherCheckDate, @UserInt
        FROM dbo.VoucherStock_Table WHERE Id = @IdInt;

        SELECT @IdInt;
    END

    ELSE IF @Action = 'UpdateCheck'
    BEGIN
        UPDATE dbo.VoucherStock_Table
           SET VoucherCheckDate = GETDATE(), CheckedBy = @CheckedBy,
               ModifiedBy = @UserInt, ModifiedDate = GETDATE()
         WHERE Id = @IdInt;

        INSERT INTO dbo.VoucherHistory_Table
            (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy, VoucherCheckDate, ChangedBy)
        SELECT Id, ProductId, VoucherCode, Status, Status, CheckedBy, VoucherCheckDate, @UserInt
        FROM dbo.VoucherStock_Table WHERE Id = @IdInt;
    END

    ELSE IF @Action = 'SelectForAssign'
        SELECT v.Id, v.VoucherCode, v.ExpiryDate, v.Status,
               ProductName = pr.Name, v.ProductId,
               AssignedToName = ISNULL(a.FullName, '')
        FROM dbo.VoucherStock_Table v
        INNER JOIN dbo.VoucherProduct_Table pr ON pr.Id = v.ProductId
        LEFT  JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE (@ProviderInt IS NULL OR v.ProviderId = @ProviderInt)
          AND (@ProductInt  IS NULL OR v.ProductId  = @ProductInt)
          AND v.AssignedTo IS NULL
        ORDER BY pr.Name, v.Id;

    ELSE IF @Action = 'Assign'
    BEGIN
        IF @Ids IS NULL OR @AssignInt IS NULL
        BEGIN
            SELECT Assigned = 0;
            RETURN;
        END

        UPDATE v
           SET AssignedTo = @AssignInt, AssignedBy = @UserInt, AssignedDate = GETDATE(),
               ModifiedBy = @UserInt, ModifiedDate = GETDATE()
        FROM dbo.VoucherStock_Table v
        INNER JOIN STRING_SPLIT(@Ids, ',') s ON v.Id = TRY_CONVERT(INT, s.value);

        SET @Ins = @@ROWCOUNT;
        SELECT Assigned = @Ins;
    END

    ELSE IF @Action = 'SelectHistory'
        SELECT h.Id, ProductName = pr.Name, h.VoucherCode, h.Status,
               h.CheckedBy, h.VoucherCheckDate, h.ChangedDate
        FROM dbo.VoucherHistory_Table h
        LEFT JOIN dbo.VoucherProduct_Table pr ON pr.Id = h.ProductId
        LEFT JOIN dbo.VoucherStock_Table   v  ON v.Id  = h.VoucherId
        WHERE (@ProviderInt IS NULL OR v.ProviderId = @ProviderInt)
        ORDER BY h.ChangedDate DESC, h.Id DESC;

    ELSE IF @Action = 'Insert'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherStock_Table WHERE VoucherCode = @VoucherCode)
        BEGIN SELECT -1; RETURN; END
        INSERT INTO dbo.VoucherStock_Table
            (ProviderId, ProductId, VoucherCode, ExpiryDate, DealerName, SaleDate, Status, AddedBy)
        VALUES (@ProviderInt, @ProductInt, @VoucherCode, @Expiry, @DealerName, @Sale,
                ISNULL(@Status, 'Unused'), @UserInt);
        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END

    ELSE IF @Action = 'Update'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherStock_Table WHERE VoucherCode = @VoucherCode AND Id <> @IdInt)
        BEGIN SELECT -1; RETURN; END
        UPDATE dbo.VoucherStock_Table
           SET ProviderId = @ProviderInt, ProductId = @ProductInt, VoucherCode = @VoucherCode,
               ExpiryDate = @Expiry, DealerName = @DealerName, SaleDate = @Sale,
               Status = ISNULL(@Status, Status), ModifiedBy = @UserInt, ModifiedDate = GETDATE()
         WHERE Id = @IdInt;
        SELECT @IdInt;
    END
END
GO

/* remove the rows created while testing the upload modal */
DELETE FROM dbo.VoucherHistory_Table
WHERE VoucherId IN (SELECT Id FROM dbo.VoucherStock_Table WHERE VoucherCode LIKE 'AWS-TEST-%');
DELETE FROM dbo.VoucherStock_Table WHERE VoucherCode LIKE 'AWS-TEST-%';
GO

PRINT 'BulkInsert count fixed';
GO
