/* ============================================================
   Revision 3 - voucher stock proc.

   *** THIS IS THE AUTHORITATIVE COPY OF Sp_VoucherStock_Table. ***
   It supersedes both 06_Revision2/03_Sp_VoucherStock.sql and
   06_Revision2/05_Admin_Edit.sql, which are two full copies of the
   same proc. Edit this file, not those.

   Changes against 06_Revision2/05_Admin_Edit.sql:

   1. @Status = 'NotSet' selects vouchers whose Status IS NULL, so
      the dashboard's new "Not Set" pill can drill through.

   2. New @Days parameter - the early-expiry window. When set, only
      vouchers expiring between today and today + N days come back.
      This is what makes the dashboard count and the View Data row
      count agree after picking 1 Day / 3 Days / 7 Days / 1 Month.

   3. SelectCount also reports NotSetVoucher.

   Revision 3b adds:

   4. @ExpiryDate doubles as a grid filter (it was only ever used by
      the insert/update branches).

   5. AutoMove - the overnight sweep. Setting a status or ticking the
      check box stamps AutoMoveAfter with the next midnight; this
      action moves everything whose moment has passed. Reassign
      clears the stamp so a returned voucher is not snatched back.

   6. ReassignMany - sub-admin reassigns a batch in one go.

   7. UpdateStatusOnly - the student's status buttons. It touches
      Status and UsedDate only. UpdateStatusEntry overwrites
      CandidateName / ExamDate / ExamMode with whatever it is handed,
      so a student saving from a status-only editor would silently
      wipe fields they were never shown.

   Revision 3c:

   8. UpdateAdminEntry no longer writes VoucherCode. The admin's
      editor shows the code but greys it out, and the proc will not
      change it whatever is posted. It gained Status and UsedDate,
      which the admin may now set.

   Revision 3d - encryption:

   9. VoucherCode, CandidateName, Remarks and the dealer names are
      VARBINARY ciphertext. Run 08_Encryption/01 before this file;
      without VoucherDataKey the proc refuses to run rather than
      quietly handing back NULLs.

      Duplicate voucher codes are caught on VoucherCodeHash, not on
      the code, because the same code encrypts differently every
      time. Anything new that inserts a voucher must set both.

      The VoucherHistory_Table inserts below copy v.VoucherCode
      straight across. That is deliberate - both columns hold
      ciphertext under the same key, so the bytes carry over and
      there is nothing to decrypt and re-encrypt.
   ============================================================ */
USE DSL_New;
GO

/* VoucherStock_Table carries a filtered index on AutoMoveAfter, and a proc is
   stamped with the QUOTED_IDENTIFIER in force when it was created. sqlcmd
   defaults that OFF, so running this file with plain sqlcmd bakes OFF into the
   proc and every UPDATE branch then fails with msg 1934 at runtime - Move,
   Reassign, AutoMove, BulkInsert, all of them, while the SELECTs carry on
   working. Set it here so the file is safe whatever runs it. */
SET QUOTED_IDENTIFIER ON;
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
    @Status           NVARCHAR(20)   = NULL,
    @VoucherCheckDate NVARCHAR(30)   = NULL,
    @CheckedBy        NVARCHAR(100)  = NULL,
    @UsedDate         NVARCHAR(30)   = NULL,
    @CandidateName    NVARCHAR(150)  = NULL,
    @ExamDate         NVARCHAR(30)   = NULL,
    @ExamMode         NVARCHAR(50)   = NULL,
    @AssignedTo       NVARCHAR(50)   = NULL,
    @IsMoved          NVARCHAR(5)    = NULL,
    @Days             NVARCHAR(10)   = NULL,
    @Ids              NVARCHAR(MAX)  = NULL,
    @Data             NVARCHAR(MAX)  = NULL,
    /* BulkInsert only: the dealer pairs pasted alongside each voucher, as
       "code|seq|name|saledate" records separated by ~. Kept apart from @Data
       because a voucher carries any number of pairs and @Data is one record
       per voucher. */
    @DealerData       NVARCHAR(MAX)  = NULL,
    @AddedBy          NVARCHAR(50)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    /* Voucher codes, candidate names, dealer names and remarks live in this
       table as ciphertext - see 08_Encryption. Everything below reads and
       writes them through this key.

       The key stays open for the rest of the connection. Left closed,
       DECRYPTBYKEY does not complain, it just returns NULL: grids would fill
       with blank voucher codes and an upload would happily store rows nobody
       can read. So this refuses to run instead. */
    IF NOT EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'VoucherDataKey')
        OPEN SYMMETRIC KEY VoucherDataKey DECRYPTION BY CERTIFICATE VoucherDataCert;

    IF NOT EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'VoucherDataKey')
    BEGIN
        RAISERROR('VoucherDataKey could not be opened. Voucher data cannot be read or written. Check that VoucherDataCert exists and that this login has VIEW DEFINITION on both.', 16, 1);
        RETURN;
    END

    DECLARE @IdInt       INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@Id)), ''));
    DECLARE @ProviderInt INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@ProviderId)), ''));
    DECLARE @ProductInt  INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@ProductId)), ''));
    DECLARE @UserInt     INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@AddedBy)), ''));
    DECLARE @AssignInt   INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@AssignedTo)), ''));
    DECLARE @MovedBit    INT  = TRY_CONVERT(INT,  NULLIF(LTRIM(RTRIM(@IsMoved)), ''));
    DECLARE @Expiry      DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ExpiryDate)), ''));
    DECLARE @Sale        DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@SaleDate)), ''));
    DECLARE @Used        DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@UsedDate)), ''));
    DECLARE @Exam        DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@ExamDate)), ''));
    DECLARE @CheckDt     DATE = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@VoucherCheckDate)), ''));
    DECLARE @Ins         INT  = 0;
    DECLARE @Total       INT  = 0;
    DECLARE @Old         NVARCHAR(20);
    DECLARE @NewStudent  NVARCHAR(150);

    /* early-expiry window - NULL means no expiry restriction */
    DECLARE @Today  DATE = CAST(GETDATE() AS DATE);
    DECLARE @DayInt INT  = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@Days)), ''));
    DECLARE @WinEnd DATE = CASE WHEN @DayInt IS NULL THEN NULL
                                ELSE DATEADD(DAY, @DayInt, @Today) END;

    /* tonight's midnight - when a voucher checked today becomes the
       sub-admin's, without anyone pressing anything */
    DECLARE @NextMidnight DATETIME = DATEADD(DAY, 1, CAST(@Today AS DATETIME));

    SET @VoucherCode   = NULLIF(LTRIM(RTRIM(@VoucherCode)), '');
    SET @DealerName    = NULLIF(LTRIM(RTRIM(@DealerName)),  '');
    SET @CheckedBy     = NULLIF(LTRIM(RTRIM(@CheckedBy)),   '');
    SET @Status        = NULLIF(LTRIM(RTRIM(@Status)),      '');
    SET @CandidateName = NULLIF(LTRIM(RTRIM(@CandidateName)), '');
    SET @ExamMode      = NULLIF(LTRIM(RTRIM(@ExamMode)),    '');

    IF @Status = 'All' SET @Status = NULL;

    /* ================= grid ================= */
    IF @Action IN ('Select', 'SelectAll', 'SelectFilter', 'SelectExport', 'SelectDone')
    BEGIN
        IF @Action = 'SelectDone' SET @MovedBit = 1;

        SELECT
            v.Id, v.ProviderId, ProviderName = p.Name,
            v.ProductId, ProductName = pr.Name,
            VoucherCode = CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)),
            v.ExpiryDate,
            AddedByName = ISNULL(u.FullName, ''),
            DealerNames = ISNULL((
                SELECT STRING_AGG(ISNULL(CONVERT(NVARCHAR(300), DECRYPTBYKEY(d.DealerName)), ''), '|')
                       WITHIN GROUP (ORDER BY d.Seq)
                FROM dbo.VoucherDealer_Table d WHERE d.VoucherId = v.Id), ''),
            SaleDates = ISNULL((
                SELECT STRING_AGG(ISNULL(CONVERT(VARCHAR(10), d.SaleDate, 23), ''), '|')
                       WITHIN GROUP (ORDER BY d.Seq)
                FROM dbo.VoucherDealer_Table d WHERE d.VoucherId = v.Id), ''),
            DealerCount = (SELECT COUNT(*) FROM dbo.VoucherDealer_Table d WHERE d.VoucherId = v.Id),
            v.Status, v.UsedDate, v.VoucherCheckDate, v.CheckedBy,
            CandidateName = CONVERT(NVARCHAR(300), DECRYPTBYKEY(v.CandidateName)),
            v.ExamDate, v.ExamMode,
            v.AssignedTo, AssignedToName = ISNULL(a.FullName, ''),
            v.IsMoved, v.MovedDate, v.AutoMoveAfter,
            Remarks = CONVERT(NVARCHAR(1000), DECRYPTBYKEY(v.Remarks)),
            v.AddedDate
        FROM dbo.VoucherStock_Table v
        INNER JOIN dbo.VoucherProvider_Table p  ON p.Id  = v.ProviderId
        INNER JOIN dbo.VoucherProduct_Table  pr ON pr.Id = v.ProductId
        LEFT  JOIN dbo.User_Table u ON u.Id = v.AddedBy
        LEFT  JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE (@ProviderInt IS NULL OR v.ProviderId  = @ProviderInt)
          AND (@ProductInt  IS NULL OR v.ProductId   = @ProductInt)
          /* A partial match cannot use an index on ciphertext - this decrypts
             every candidate row. Fine at this table's size; if it ever grows
             past a few tens of thousands, search will need rethinking. */
          AND (@VoucherCode IS NULL
               OR CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)) LIKE '%' + @VoucherCode + '%')
          AND (@CheckedBy   IS NULL OR v.CheckedBy   = @CheckedBy)
          AND (@Status      IS NULL
               OR (@Status =  'NotSet' AND v.Status IS NULL)
               OR (@Status <> 'NotSet' AND v.Status = @Status))
          AND (@WinEnd      IS NULL
               OR (v.ExpiryDate IS NOT NULL AND v.ExpiryDate BETWEEN @Today AND @WinEnd))
          AND (@Expiry      IS NULL OR v.ExpiryDate = @Expiry)
          AND (@CheckDt     IS NULL OR CAST(v.VoucherCheckDate AS DATE) = @CheckDt)
          AND (@AssignInt   IS NULL OR v.AssignedTo  = @AssignInt)
          AND (@MovedBit    IS NULL OR v.IsMoved     = @MovedBit)
          AND (@DealerName  IS NULL OR EXISTS (
                  SELECT 1 FROM dbo.VoucherDealer_Table d
                  WHERE d.VoucherId = v.Id
                    AND CONVERT(NVARCHAR(300), DECRYPTBYKEY(d.DealerName))
                        LIKE '%' + @DealerName + '%'))
        ORDER BY v.Id DESC;
    END

    ELSE IF @Action = 'SelectId'
        SELECT v.Id, v.ProviderId, v.ProductId,
               VoucherCode = CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)),
               v.ExpiryDate,
               v.Status, v.UsedDate, v.VoucherCheckDate, v.CheckedBy,
               CandidateName = CONVERT(NVARCHAR(300), DECRYPTBYKEY(v.CandidateName)),
               v.ExamDate, v.ExamMode, v.AssignedTo,
               v.IsMoved,
               Remarks = CONVERT(NVARCHAR(1000), DECRYPTBYKEY(v.Remarks)),
               AddedByName = ISNULL(u.FullName, ''),
               DealerNames = ISNULL((
                   SELECT STRING_AGG(ISNULL(CONVERT(NVARCHAR(300), DECRYPTBYKEY(d.DealerName)), ''), '|')
                          WITHIN GROUP (ORDER BY d.Seq)
                   FROM dbo.VoucherDealer_Table d WHERE d.VoucherId = v.Id), ''),
               SaleDates = ISNULL((
                   SELECT STRING_AGG(ISNULL(CONVERT(VARCHAR(10), d.SaleDate, 23), ''), '|')
                          WITHIN GROUP (ORDER BY d.Seq)
                   FROM dbo.VoucherDealer_Table d WHERE d.VoucherId = v.Id), ''),
               DealerCount = (SELECT COUNT(*) FROM dbo.VoucherDealer_Table d WHERE d.VoucherId = v.Id)
        FROM dbo.VoucherStock_Table v
        LEFT JOIN dbo.User_Table u ON u.Id = v.AddedBy
        WHERE v.Id = @IdInt;

    /* Every active student, whether they have checked anything or not - the
       filter is a list of people, so a student who has done nothing yet still
       belongs in it (and picking them is a fair way to see that they have done
       nothing).

       Unioned with whoever else actually appears in CheckedBy for this provider,
       so a sub-admin who checked a voucher does not vanish from the filter. That
       half stays provider-scoped: a name from another provider would only ever
       return an empty grid.

       CheckedBy holds the person's FullName, so these must be names, not ids. */
    ELSE IF @Action = 'SelectCheckedBy'
        SELECT DISTINCT x.CheckedBy
        FROM (
            SELECT CheckedBy = u.FullName
            FROM dbo.User_Table u
            INNER JOIN dbo.UserTypeMaster t ON t.Id = u.[Type]
            WHERE t.TypeId = 4
              AND t.UserTypeName = 'Voucher Student'
              AND u.Status = 1

            UNION

            SELECT v.CheckedBy
            FROM dbo.VoucherStock_Table v
            WHERE v.CheckedBy IS NOT NULL AND v.CheckedBy <> ''
              AND (@ProviderInt IS NULL OR v.ProviderId = @ProviderInt)
        ) x
        WHERE x.CheckedBy IS NOT NULL AND x.CheckedBy <> ''
        ORDER BY x.CheckedBy;

    ELSE IF @Action = 'SelectDealerColumns'
        SELECT MaxSeq = ISNULL(MAX(d.Seq), 1)
        FROM dbo.VoucherDealer_Table d
        INNER JOIN dbo.VoucherStock_Table v ON v.Id = d.VoucherId
        WHERE (@ProviderInt IS NULL OR v.ProviderId = @ProviderInt);

    ELSE IF @Action = 'SelectCount'
        SELECT TotalVoucher   = COUNT(*),
               UsedVoucher    = SUM(CASE WHEN Status = 'Used'    THEN 1 ELSE 0 END),
               UnusedVoucher  = SUM(CASE WHEN Status = 'Unused'  THEN 1 ELSE 0 END),
               ExpiredVoucher = SUM(CASE WHEN Status = 'Expired' THEN 1 ELSE 0 END),
               InvalidVoucher = SUM(CASE WHEN Status = 'Invalid' THEN 1 ELSE 0 END),
               NotSetVoucher  = SUM(CASE WHEN Status IS NULL     THEN 1 ELSE 0 END),
               CheckedVoucher = SUM(CASE WHEN VoucherCheckDate IS NOT NULL THEN 1 ELSE 0 END)
        FROM dbo.VoucherStock_Table
        WHERE (@ProviderInt IS NULL OR ProviderId = @ProviderInt);

    /* ================= upload entry ================= */
    ELSE IF @Action = 'BulkInsert'
    BEGIN
        IF @ProductInt IS NULL OR @Data IS NULL
        BEGIN
            SELECT Inserted = 0, Skipped = 0;
            RETURN;
        END

        DECLARE @Rows TABLE (Code NVARCHAR(100) PRIMARY KEY, Expiry DATE);

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

        /* What actually went in, so the dealer pairs below can be attached to
           those rows and only those - a code that was skipped as a duplicate
           already belongs to somebody, and its dealers are not ours to touch. */
        DECLARE @New TABLE (Id INT PRIMARY KEY, CodeHash VARBINARY(32));

        /* The duplicate check compares hashes, not codes. Two uploads of the
           same code encrypt to different bytes, so comparing the stored
           ciphertext would let every duplicate straight through. */
        INSERT INTO dbo.VoucherStock_Table
            (ProviderId, ProductId, VoucherCode, VoucherCodeHash, ExpiryDate, Status, AddedBy)
        OUTPUT inserted.Id, inserted.VoucherCodeHash INTO @New (Id, CodeHash)
        SELECT pr.ProviderId, @ProductInt,
               ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'), r.Code),
               HASHBYTES('SHA2_256', r.Code),
               r.Expiry, NULL, @UserInt
        FROM @Rows r
        CROSS APPLY (SELECT ProviderId FROM dbo.VoucherProduct_Table WHERE Id = @ProductInt) pr
        WHERE NOT EXISTS (SELECT 1 FROM dbo.VoucherStock_Table v
                          WHERE v.VoucherCodeHash = HASHBYTES('SHA2_256', r.Code));

        SET @Ins = @@ROWCOUNT;

        /* ---- the dealer pairs that came with them ----
           Split by position rather than by STRING_SPLIT's row order: that
           order is not guaranteed, and here it would decide which value is
           the name and which the date. Seq travels in the record for the
           same reason - it is the paste's column order, not a row number. */
        IF @DealerData IS NOT NULL AND LTRIM(RTRIM(@DealerData)) <> ''
            INSERT INTO dbo.VoucherDealer_Table (VoucherId, Seq, DealerName, SaleDate)
            SELECT n.Id, d.Seq,
                   ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'), NULLIF(d.Nm, '')),
                   TRY_CONVERT(DATE, NULLIF(d.Dt, ''))
            FROM (
                SELECT Code = LTRIM(RTRIM(f1.Head)),
                       Seq  = TRY_CONVERT(INT, f2.Head),
                       Nm   = LTRIM(RTRIM(f3.Head)),
                       Dt   = LTRIM(RTRIM(f3.Tail))
                FROM STRING_SPLIT(@DealerData, '~') s
                CROSS APPLY (SELECT Head = LEFT(s.value, CHARINDEX('|', s.value + '|') - 1),
                                    Tail = SUBSTRING(s.value, CHARINDEX('|', s.value + '|') + 1, 4000)) f1
                CROSS APPLY (SELECT Head = LEFT(f1.Tail, CHARINDEX('|', f1.Tail + '|') - 1),
                                    Tail = SUBSTRING(f1.Tail, CHARINDEX('|', f1.Tail + '|') + 1, 4000)) f2
                CROSS APPLY (SELECT Head = LEFT(f2.Tail, CHARINDEX('|', f2.Tail + '|') - 1),
                                    Tail = SUBSTRING(f2.Tail, CHARINDEX('|', f2.Tail + '|') + 1, 4000)) f3
                WHERE LTRIM(RTRIM(s.value)) <> ''
            ) d
            INNER JOIN @New n ON n.CodeHash = HASHBYTES('SHA2_256', d.Code)
            WHERE d.Seq IS NOT NULL AND (d.Nm <> '' OR d.Dt <> '');

        SELECT Inserted = @Ins, Skipped = @Total - @Ins;
    END

    /* ================= dealers ================= */
    ELSE IF @Action = 'SaveDealers'
    BEGIN
        DELETE FROM dbo.VoucherDealer_Table WHERE VoucherId = @IdInt;

        IF @Data IS NOT NULL AND LTRIM(RTRIM(@Data)) <> ''
            INSERT INTO dbo.VoucherDealer_Table (VoucherId, Seq, DealerName, SaleDate)
            SELECT @IdInt,
                   ROW_NUMBER() OVER (ORDER BY x.Ord),
                   ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'), NULLIF(x.Nm, '')),
                   TRY_CONVERT(DATE, NULLIF(x.Dt, ''))
            FROM (
                SELECT Ord = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
                       Nm  = LTRIM(RTRIM(LEFT(s.value, CHARINDEX('|', s.value + '|') - 1))),
                       Dt  = LTRIM(RTRIM(SUBSTRING(s.value, CHARINDEX('|', s.value + '|') + 1, 4000)))
                FROM STRING_SPLIT(@Data, '~') s
            ) x
            WHERE x.Nm <> '' OR x.Dt <> '';

        UPDATE dbo.VoucherStock_Table
           SET ModifiedBy = @UserInt, ModifiedDate = GETDATE()
         WHERE Id = @IdInt;

        SELECT @IdInt;
    END

    /* ================= admin edit =================
       Expiry date, check date, status and used date. Dealer names go
       through SaveDealers.

       VoucherCode, AddedBy, CandidateName, ExamDate and ExamMode are
       deliberately NOT touched - the admin's editor shows them
       greyed out, and the proc must not change them even if a value
       is posted. */
    ELSE IF @Action = 'UpdateAdminEntry'
    BEGIN
        UPDATE dbo.VoucherStock_Table
           SET ExpiryDate       = @Expiry,
               VoucherCheckDate = @CheckDt,
               Status           = @Status,
               UsedDate         = CASE WHEN @Status = 'Used' THEN @Used ELSE NULL END,
               ModifiedBy       = @UserInt,
               ModifiedDate     = GETDATE()
         WHERE Id = @IdInt;

        INSERT INTO dbo.VoucherHistory_Table
            (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
             VoucherCheckDate, ChangedBy, Activity, AssignedToName)
        SELECT v.Id, v.ProductId, v.VoucherCode, v.Status, v.Status, v.CheckedBy,
               v.VoucherCheckDate, @UserInt, 'Admin Edit', ISNULL(a.FullName, '')
        FROM dbo.VoucherStock_Table v
        LEFT JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE v.Id = @IdInt;

        SELECT @IdInt;
    END

    /* ================= status entry ================= */
    ELSE IF @Action = 'UpdateStatusEntry'
    BEGIN
        SET @Old = (SELECT Status FROM dbo.VoucherStock_Table WHERE Id = @IdInt);

        UPDATE dbo.VoucherStock_Table
           SET Status           = ISNULL(@Status, Status),
               UsedDate         = CASE WHEN @Status = 'Used' THEN @Used ELSE NULL END,
               CandidateName    = ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'), @CandidateName),
               ExamDate         = @Exam,
               ExamMode         = @ExamMode,
               VoucherCheckDate = GETDATE(),
               CheckedBy        = @CheckedBy,
               AutoMoveAfter    = @NextMidnight,
               ModifiedBy       = @UserInt,
               ModifiedDate     = GETDATE()
         WHERE Id = @IdInt;

        INSERT INTO dbo.VoucherHistory_Table
            (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
             VoucherCheckDate, ChangedBy, Activity, AssignedToName)
        SELECT v.Id, v.ProductId, v.VoucherCode, @Old, v.Status, v.CheckedBy,
               v.VoucherCheckDate, @UserInt, 'Status Update', ISNULL(a.FullName, '')
        FROM dbo.VoucherStock_Table v
        LEFT JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE v.Id = @IdInt;

        SELECT @IdInt;
    END

    ELSE IF @Action = 'UpdateCheck'
    BEGIN
        UPDATE dbo.VoucherStock_Table
           SET VoucherCheckDate = GETDATE(), CheckedBy = @CheckedBy,
               AutoMoveAfter = @NextMidnight,
               ModifiedBy = @UserInt, ModifiedDate = GETDATE()
         WHERE Id = @IdInt;

        INSERT INTO dbo.VoucherHistory_Table
            (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
             VoucherCheckDate, ChangedBy, Activity, AssignedToName)
        SELECT v.Id, v.ProductId, v.VoucherCode, v.Status, v.Status, v.CheckedBy,
               v.VoucherCheckDate, @UserInt, 'Voucher Checked', ISNULL(a.FullName, '')
        FROM dbo.VoucherStock_Table v
        LEFT JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE v.Id = @IdInt;
    END

    /* ================= move / reassign ================= */
    ELSE IF @Action = 'Move'
    BEGIN
        UPDATE dbo.VoucherStock_Table
           SET IsMoved = 1, MovedDate = GETDATE(), MovedBy = @UserInt,
               ModifiedBy = @UserInt, ModifiedDate = GETDATE()
         WHERE Id = @IdInt
           AND Status IS NOT NULL
           AND VoucherCheckDate IS NOT NULL;

        SET @Ins = @@ROWCOUNT;

        IF @Ins > 0
            INSERT INTO dbo.VoucherHistory_Table
                (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
                 VoucherCheckDate, ChangedBy, Activity, AssignedToName)
            SELECT v.Id, v.ProductId, v.VoucherCode, v.Status, v.Status, v.CheckedBy,
                   v.VoucherCheckDate, @UserInt, 'Moved to Sub Admin', ISNULL(a.FullName, '')
            FROM dbo.VoucherStock_Table v
            LEFT JOIN dbo.User_Table a ON a.Id = v.AssignedTo
            WHERE v.Id = @IdInt;

        SELECT Moved = @Ins;
    END

    ELSE IF @Action = 'Reassign'
    BEGIN
        IF @AssignInt IS NULL
        BEGIN
            SELECT Reassigned = 0;
            RETURN;
        END

        SET @NewStudent = (SELECT FullName FROM dbo.User_Table WHERE Id = @AssignInt);

        /* AutoMoveAfter goes back to NULL - otherwise the sweep would
           take the voucher straight back off the student again */
        UPDATE dbo.VoucherStock_Table
           SET AssignedTo = @AssignInt, AssignedBy = @UserInt, AssignedDate = GETDATE(),
               IsMoved = 0, MovedDate = NULL, MovedBy = NULL, AutoMoveAfter = NULL,
               ModifiedBy = @UserInt, ModifiedDate = GETDATE()
         WHERE Id = @IdInt;

        SET @Ins = @@ROWCOUNT;

        IF @Ins > 0
            INSERT INTO dbo.VoucherHistory_Table
                (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
                 VoucherCheckDate, ChangedBy, Activity, AssignedToName)
            SELECT Id, ProductId, VoucherCode, Status, Status, CheckedBy,
                   VoucherCheckDate, @UserInt, 'Reassigned to Student', @NewStudent
            FROM dbo.VoucherStock_Table WHERE Id = @IdInt;

        SELECT Reassigned = @Ins;
    END

    /* ---------- reassign a batch in one go ---------- */
    ELSE IF @Action = 'ReassignMany'
    BEGIN
        IF @Ids IS NULL OR @AssignInt IS NULL
        BEGIN
            SELECT Reassigned = 0;
            RETURN;
        END

        SET @NewStudent = (SELECT FullName FROM dbo.User_Table WHERE Id = @AssignInt);

        UPDATE v
           SET AssignedTo = @AssignInt, AssignedBy = @UserInt, AssignedDate = GETDATE(),
               IsMoved = 0, MovedDate = NULL, MovedBy = NULL, AutoMoveAfter = NULL,
               ModifiedBy = @UserInt, ModifiedDate = GETDATE()
        FROM dbo.VoucherStock_Table v
        INNER JOIN STRING_SPLIT(@Ids, ',') s ON v.Id = TRY_CONVERT(INT, s.value);

        SET @Ins = @@ROWCOUNT;

        INSERT INTO dbo.VoucherHistory_Table
            (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
             VoucherCheckDate, ChangedBy, Activity, AssignedToName)
        SELECT v.Id, v.ProductId, v.VoucherCode, v.Status, v.Status, v.CheckedBy,
               v.VoucherCheckDate, @UserInt, 'Reassigned to Student', @NewStudent
        FROM dbo.VoucherStock_Table v
        INNER JOIN STRING_SPLIT(@Ids, ',') s ON v.Id = TRY_CONVERT(INT, s.value);

        SELECT Reassigned = @Ins;
    END

    /* ---------- overnight sweep ---------- */
    ELSE IF @Action = 'AutoMove'
    BEGIN
        DECLARE @Moved TABLE (Id INT);

        UPDATE dbo.VoucherStock_Table
           SET IsMoved = 1, MovedDate = GETDATE(), MovedBy = AssignedTo,
               ModifiedDate = GETDATE()
        OUTPUT inserted.Id INTO @Moved
         WHERE IsMoved = 0
           AND AssignedTo IS NOT NULL      -- only a student's voucher can move
           AND AutoMoveAfter IS NOT NULL
           AND AutoMoveAfter <= GETDATE();

        SET @Ins = @@ROWCOUNT;

        IF @Ins > 0
            INSERT INTO dbo.VoucherHistory_Table
                (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
                 VoucherCheckDate, ChangedBy, Activity, AssignedToName)
            SELECT v.Id, v.ProductId, v.VoucherCode, v.Status, v.Status, v.CheckedBy,
                   v.VoucherCheckDate, v.AssignedTo, 'Auto Moved to Sub Admin',
                   ISNULL(a.FullName, '')
            FROM dbo.VoucherStock_Table v
            INNER JOIN @Moved m ON m.Id = v.Id
            LEFT  JOIN dbo.User_Table a ON a.Id = v.AssignedTo;

        SELECT Moved = @Ins;
    END

    /* ---------- student status buttons: status and used date only ----------

       AssignedTo = @UserInt is the security check, not a convenience. The
       voucher id arrives from a hidden field, which is the caller's to edit -
       a student was able to open one of their own vouchers, swap the id for
       someone else's and save, stamping their own name on another student's
       row. Anything that trusts the posted id has to re-check ownership here,
       because here is the only place that cannot be tampered with. */
    ELSE IF @Action = 'UpdateStatusOnly'
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.VoucherStock_Table
                        WHERE Id = @IdInt AND AssignedTo = @UserInt)
        BEGIN
            SELECT -3;              -- not this student's voucher
            RETURN;
        END

        SET @Old = (SELECT Status FROM dbo.VoucherStock_Table WHERE Id = @IdInt);

        UPDATE dbo.VoucherStock_Table
           SET Status           = ISNULL(@Status, Status),
               UsedDate         = CASE WHEN @Status = 'Used' THEN ISNULL(@Used, @Today) ELSE NULL END,
               VoucherCheckDate = GETDATE(),
               CheckedBy        = @CheckedBy,
               AutoMoveAfter    = @NextMidnight,
               ModifiedBy       = @UserInt,
               ModifiedDate     = GETDATE()
         WHERE Id = @IdInt
           AND AssignedTo = @UserInt;

        INSERT INTO dbo.VoucherHistory_Table
            (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
             VoucherCheckDate, ChangedBy, Activity, AssignedToName)
        SELECT v.Id, v.ProductId, v.VoucherCode, @Old, v.Status, v.CheckedBy,
               v.VoucherCheckDate, @UserInt, 'Status Update', ISNULL(a.FullName, '')
        FROM dbo.VoucherStock_Table v
        LEFT JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE v.Id = @IdInt;

        SELECT @IdInt;
    END

    /* ================= assignment ================= */
    ELSE IF @Action = 'SelectForAssign'
        SELECT v.Id,
               VoucherCode = CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)),
               v.ExpiryDate, v.Status,
               ProductName = pr.Name, v.ProductId,
               AssignedToName = ISNULL(a.FullName, '')
        FROM dbo.VoucherStock_Table v
        INNER JOIN dbo.VoucherProduct_Table pr ON pr.Id = v.ProductId
        LEFT  JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE (@ProviderInt IS NULL OR v.ProviderId = @ProviderInt)
          AND (@ProductInt  IS NULL OR v.ProductId  = @ProductInt)
          AND v.AssignedTo IS NULL
        ORDER BY pr.Name, v.Id;

    /* The done list, offered in the same picker Assign uses. Reassign is the
       same job pointed at vouchers that have already come back from a student,
       rather than ones nobody has held yet. */
    ELSE IF @Action = 'SelectForReassign'
        SELECT v.Id,
               VoucherCode = CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)),
               v.ExpiryDate, v.Status,
               ProductName = pr.Name, v.ProductId,
               AssignedToName = ISNULL(a.FullName, '')
        FROM dbo.VoucherStock_Table v
        INNER JOIN dbo.VoucherProduct_Table pr ON pr.Id = v.ProductId
        LEFT  JOIN dbo.User_Table a ON a.Id = v.AssignedTo
        WHERE (@ProviderInt IS NULL OR v.ProviderId = @ProviderInt)
          AND (@ProductInt  IS NULL OR v.ProductId  = @ProductInt)
          AND v.IsMoved = 1
        ORDER BY pr.Name, v.Id;

    ELSE IF @Action = 'Assign'
    BEGIN
        IF @Ids IS NULL OR @AssignInt IS NULL
        BEGIN
            SELECT Assigned = 0;
            RETURN;
        END

        SET @NewStudent = (SELECT FullName FROM dbo.User_Table WHERE Id = @AssignInt);

        UPDATE v
           SET AssignedTo = @AssignInt, AssignedBy = @UserInt, AssignedDate = GETDATE(),
               IsMoved = 0, ModifiedBy = @UserInt, ModifiedDate = GETDATE()
        FROM dbo.VoucherStock_Table v
        INNER JOIN STRING_SPLIT(@Ids, ',') s ON v.Id = TRY_CONVERT(INT, s.value);

        SET @Ins = @@ROWCOUNT;

        INSERT INTO dbo.VoucherHistory_Table
            (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
             VoucherCheckDate, ChangedBy, Activity, AssignedToName)
        SELECT v.Id, v.ProductId, v.VoucherCode, v.Status, v.Status, v.CheckedBy,
               v.VoucherCheckDate, @UserInt, 'Assigned to Student', @NewStudent
        FROM dbo.VoucherStock_Table v
        INNER JOIN STRING_SPLIT(@Ids, ',') s ON v.Id = TRY_CONVERT(INT, s.value);

        SELECT Assigned = @Ins;
    END

    /* ================= history ================= */
    ELSE IF @Action = 'SelectHistory'
        SELECT h.Id, ProductName = pr.Name,
               VoucherCode = CONVERT(NVARCHAR(200), DECRYPTBYKEY(h.VoucherCode)),
               h.Status,
               h.CheckedBy, h.VoucherCheckDate, h.ChangedDate,
               h.Activity, h.AssignedToName
        FROM dbo.VoucherHistory_Table h
        LEFT JOIN dbo.VoucherProduct_Table pr ON pr.Id = h.ProductId
        LEFT JOIN dbo.VoucherStock_Table   v  ON v.Id  = h.VoucherId
        WHERE (@ProviderInt IS NULL OR v.ProviderId = @ProviderInt)
        ORDER BY h.ChangedDate DESC, h.Id DESC;

    /* ---------- the life of one voucher ----------
       Oldest first, because this is read as a story: assigned, checked,
       reassigned, checked again. ChangedBy is the person who did it, so a
       row can say who assigned as well as who it was assigned to.

       Round numbers each hand-off so the caller can say "assigned 3 times"
       without counting rows itself: it climbs on every assign or reassign
       and every row after one carries that number. */
    ELSE IF @Action = 'SelectVoucherHistory'
    BEGIN
        ;WITH Ordered AS
        (
            SELECT h.Id, h.Activity, h.Status, h.OldStatus,
                   h.CheckedBy, h.VoucherCheckDate, h.ChangedDate,
                   h.AssignedToName, h.ChangedBy,
                   Handoff = CASE WHEN h.Activity IN ('Assigned to Student',
                                                      'Reassigned to Student')
                                  THEN 1 ELSE 0 END
            FROM dbo.VoucherHistory_Table h
            WHERE h.VoucherId = @IdInt
        )
        SELECT o.Id, o.Activity, o.Status, o.OldStatus,
               o.CheckedBy, o.VoucherCheckDate, o.ChangedDate,
               o.AssignedToName,
               ChangedByName = ISNULL(u.FullName, ''),
               Round = SUM(o.Handoff) OVER (ORDER BY o.ChangedDate, o.Id
                                            ROWS UNBOUNDED PRECEDING)
        FROM Ordered o
        LEFT JOIN dbo.User_Table u ON u.Id = o.ChangedBy
        ORDER BY o.ChangedDate, o.Id;
    END

    ELSE IF @Action = 'Insert'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.VoucherStock_Table
                    WHERE VoucherCodeHash = HASHBYTES('SHA2_256', @VoucherCode))
        BEGIN SELECT -1; RETURN; END
        INSERT INTO dbo.VoucherStock_Table
            (ProviderId, ProductId, VoucherCode, VoucherCodeHash, ExpiryDate, Status, AddedBy)
        VALUES (@ProviderInt, @ProductInt,
                ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'), @VoucherCode),
                HASHBYTES('SHA2_256', @VoucherCode),
                @Expiry, @Status, @UserInt);
        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END
END
GO

PRINT 'Sp_VoucherStock_Table updated (Not Set filter, early-expiry window, encrypted columns)';
GO
