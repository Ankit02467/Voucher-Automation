/* ============================================================
   DEVELOPMENT SEED - NEVER RUN THIS ON PRODUCTION.

   Deliberately numbered 99 and kept outside the 01..07 migration
   chain, because Database/README.md tells you to run those folders
   in numeric order. Nothing in here should ever be swept up by that.

   Creates ~120 vouchers spread across every active product, with a
   mix designed to make each screen show something interesting:

     - statuses including NULL, so the "Not Set" pill has rows
     - expiry dates bunched near today, so the 1 / 3 / 7 Day and
       1 Month early-expiry windows each return a different count
     - some assigned to students and already checked, so Student wise
       Performance has Today, Weekly and Monthly figures that differ
     - some already moved, so the sub-admin's Done Entries is not empty
     - a few codes containing spaces ("DEMO CODE 0017"), because real
       codes do and splitting on space would break them
     - dealers on some rows, so the pivoted Dealer Name columns fill

   Every row it creates has a code starting "DEMO", which is also how
   it cleans up after itself - so it is re-runnable, and
   99_DevSeed/02_Remove_Dummy_Vouchers.sql undoes it completely.
   ============================================================ */
USE DSL_New;
GO

/* Filtered index on AutoMoveAfter - see CLAUDE.md trap 7. */
SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

/* Voucher codes, candidate names and dealer names are encrypted - see
   08_Encryption. This seed writes and matches through the key like the proc
   does, which is also why "DEMO%" has to be decrypted before it can be
   compared. */
IF NOT EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'VoucherDataKey')
    OPEN SYMMETRIC KEY VoucherDataKey DECRYPTION BY CERTIFICATE VoucherDataCert;

IF NOT EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'VoucherDataKey')
BEGIN
    RAISERROR('VoucherDataKey is not open - run 08_Encryption/01 first.', 16, 1);
    RETURN;
END

DECLARE @Admin    INT  = (SELECT TOP 1 Id FROM dbo.User_Table WHERE Email = 'voucher.admin@dsucceedlearners.com');
DECLARE @SubAdmin INT  = (SELECT TOP 1 Id FROM dbo.User_Table WHERE Email = 'voucher.subadmin@dsucceedlearners.com');
DECLARE @Today    DATE = CAST(GETDATE() AS DATE);
DECLARE @Midnight DATETIME = DATEADD(DAY, 1, CAST(CAST(GETDATE() AS DATE) AS DATETIME));

IF @Admin IS NULL
BEGIN
    RAISERROR('Voucher Admin user not found - run 05_ViewData/05_Seed_VoucherUsers.sql first.', 16, 1);
    RETURN;
END

/* ---------- clear anything a previous run left ---------- */
DELETE h FROM dbo.VoucherHistory_Table h
 INNER JOIN dbo.VoucherStock_Table v ON v.Id = h.VoucherId
 WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)) LIKE 'DEMO%';

DELETE d FROM dbo.VoucherDealer_Table d
 INNER JOIN dbo.VoucherStock_Table v ON v.Id = d.VoucherId
 WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)) LIKE 'DEMO%';

DELETE FROM dbo.VoucherStock_Table
 WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(VoucherCode)) LIKE 'DEMO%';

/* ---------- what we can hang vouchers off ---------- */
DECLARE @Prod TABLE (Seq INT IDENTITY(1,1), ProductId INT, ProviderId INT);
INSERT INTO @Prod (ProductId, ProviderId)
SELECT pr.Id, pr.ProviderId
FROM dbo.VoucherProduct_Table pr
WHERE pr.Status = 'A'
ORDER BY pr.ProviderId, pr.Name;

DECLARE @Stu TABLE (Seq INT IDENTITY(1,1), UserId INT, FullName NVARCHAR(150));
INSERT INTO @Stu (UserId, FullName)
SELECT u.Id, u.FullName
FROM dbo.User_Table u
INNER JOIN dbo.UserTypeMaster t ON t.Id = u.[Type]
WHERE t.TypeId = 4 AND t.UserTypeName = 'Voucher Student' AND u.Status = 1
ORDER BY u.FullName;

DECLARE @ProdCount INT = (SELECT COUNT(*) FROM @Prod);
DECLARE @StuCount  INT = (SELECT COUNT(*) FROM @Stu);

IF @ProdCount = 0 OR @StuCount = 0
BEGIN
    RAISERROR('No active products or no students - seed the products and users first.', 16, 1);
    RETURN;
END

/* ---------- the vouchers ---------- */
;WITH n AS (
    SELECT TOP (120) rn = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
    FROM sys.all_objects
),
r AS (
    SELECT n.rn,
           p.ProductId,
           p.ProviderId,
           /* 30% untriaged, then unused / used / expired / invalid */
           Status = CASE n.rn % 10
                        WHEN 0 THEN NULL
                        WHEN 1 THEN NULL
                        WHEN 2 THEN NULL
                        WHEN 3 THEN 'Unused'
                        WHEN 4 THEN 'Unused'
                        WHEN 5 THEN 'Unused'
                        WHEN 6 THEN 'Used'
                        WHEN 7 THEN 'Used'
                        WHEN 8 THEN 'Expired'
                        ELSE        'Invalid'
                    END,
           /* clustered near today so each expiry window differs */
           Expiry = DATEADD(DAY,
                        CASE n.rn % 12
                            WHEN 0 THEN 1   WHEN 1 THEN 2   WHEN 2 THEN 3
                            WHEN 3 THEN 5   WHEN 4 THEN 7   WHEN 5 THEN 12
                            WHEN 6 THEN 20  WHEN 7 THEN 28
                            ELSE 45 + (n.rn % 180)
                        END, @Today),
           /* Every third voucher goes to a student, and the student is picked
              off rn/3 so the two cycles do not lock in phase. Deciding on
              rn % 5 while picking on rn % 5 handed every voucher to the same
              two students and left the other three with nothing. */
           StudentId   = CASE WHEN n.rn % 3 = 0 THEN s.UserId   END,
           StudentName = CASE WHEN n.rn % 3 = 0 THEN s.FullName END,
           /* checks land anywhere in the last 25 days, some of them today */
           CheckedOn   = DATEADD(DAY, -(n.rn % 25), CAST(@Today AS DATETIME))
    FROM n
    INNER JOIN @Prod p ON p.Seq = ((n.rn - 1) % @ProdCount) + 1
    INNER JOIN @Stu  s ON s.Seq = ((n.rn / 3) % @StuCount)  + 1
)
, coded AS (
    SELECT r.*,
           /* every seventeenth code carries spaces, like the real ones do */
           Code = CAST(CASE WHEN r.rn % 17 = 0
                            THEN 'DEMO CODE ' + RIGHT('000' + CAST(r.rn AS VARCHAR(4)), 4)
                            ELSE 'DEMO-'      + RIGHT('000' + CAST(r.rn AS VARCHAR(4)), 4)
                       END AS NVARCHAR(200))
    FROM r
)
INSERT INTO dbo.VoucherStock_Table
    (ProviderId, ProductId, VoucherCode, VoucherCodeHash, ExpiryDate, Status, UsedDate,
     VoucherCheckDate, CheckedBy, CandidateName, ExamDate, ExamMode,
     AssignedTo, AssignedBy, AssignedDate, IsMoved, MovedDate, MovedBy,
     AutoMoveAfter, AddedBy, AddedDate)
SELECT
    r.ProviderId,
    r.ProductId,
    ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'), r.Code),
    HASHBYTES('SHA2_256', r.Code),
    r.Expiry,
    r.Status,
    UsedDate = CASE WHEN r.Status = 'Used' THEN DATEADD(DAY, -(r.rn % 20), @Today) END,

    /* only a voucher someone holds gets checked */
    VoucherCheckDate = CASE WHEN r.Status IS NOT NULL AND r.StudentId IS NOT NULL THEN r.CheckedOn END,
    CheckedBy        = CASE WHEN r.Status IS NOT NULL AND r.StudentId IS NOT NULL THEN r.StudentName END,

    CandidateName = ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'),
                        CASE WHEN r.Status = 'Used'
                             THEN CAST('Candidate ' + CAST(r.rn AS VARCHAR(4)) AS NVARCHAR(300)) END),
    ExamDate      = CASE WHEN r.Status = 'Used' THEN DATEADD(DAY, (r.rn % 30) + 1, @Today) END,
    ExamMode      = CASE WHEN r.Status = 'Used' THEN CASE WHEN r.rn % 2 = 0 THEN 'Online' ELSE 'Test Centre' END END,

    AssignedTo   = r.StudentId,
    AssignedBy   = CASE WHEN r.StudentId IS NOT NULL THEN @SubAdmin END,
    AssignedDate = CASE WHEN r.StudentId IS NOT NULL THEN DATEADD(DAY, -(r.rn % 30) - 1, GETDATE()) END,

    /* a quarter of the checked ones have already moved on, so the
       sub-admin's Done Entries list has something in it */
    IsMoved   = CASE WHEN r.Status IS NOT NULL AND r.StudentId IS NOT NULL AND r.rn % 4 = 0 THEN 1 ELSE 0 END,
    MovedDate = CASE WHEN r.Status IS NOT NULL AND r.StudentId IS NOT NULL AND r.rn % 4 = 0 THEN r.CheckedOn END,
    MovedBy   = CASE WHEN r.Status IS NOT NULL AND r.StudentId IS NOT NULL AND r.rn % 4 = 0 THEN r.StudentId END,

    /* the rest are due tonight, so the sweep leaves them with the
       student until tomorrow instead of clearing the screen at once */
    AutoMoveAfter = CASE WHEN r.Status IS NOT NULL AND r.StudentId IS NOT NULL AND r.rn % 4 <> 0
                         THEN @Midnight END,

    AddedBy   = @Admin,
    AddedDate = DATEADD(DAY, -(r.rn % 40), GETDATE())
FROM coded r;

PRINT CONCAT('Vouchers created: ', @@ROWCOUNT);

/* ---------- dealers on roughly a third of them ---------- */
INSERT INTO dbo.VoucherDealer_Table (VoucherId, Seq, DealerName, SaleDate)
SELECT v.Id, 1,
       ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'),
           CAST('Dealer ' + CAST((v.Id % 7) + 1 AS VARCHAR(2)) AS NVARCHAR(300))),
       DATEADD(DAY, -((v.Id % 15) + 1), CAST(GETDATE() AS DATE))
FROM dbo.VoucherStock_Table v
WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)) LIKE 'DEMO%' AND v.Id % 3 = 0;

INSERT INTO dbo.VoucherDealer_Table (VoucherId, Seq, DealerName, SaleDate)
SELECT v.Id, 2,
       ENCRYPTBYKEY(KEY_GUID('VoucherDataKey'),
           CAST('Reseller ' + CAST((v.Id % 4) + 1 AS VARCHAR(2)) AS NVARCHAR(300))),
       DATEADD(DAY, -((v.Id % 9) + 1), CAST(GETDATE() AS DATE))
FROM dbo.VoucherStock_Table v
WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)) LIKE 'DEMO%' AND v.Id % 6 = 0;

PRINT 'Dealers created';

/* ---------- history, so the performance screens have figures ----------
   ChangedDate mirrors the check date, which is spread over the last 25
   days, so Today, Weekly and Monthly all come out different. */
INSERT INTO dbo.VoucherHistory_Table
    (VoucherId, ProductId, VoucherCode, OldStatus, Status, CheckedBy,
     VoucherCheckDate, ChangedBy, ChangedDate, Activity, AssignedToName)
/* v.VoucherCode goes across as it stands - both columns hold ciphertext
   under the same key, so there is nothing to decrypt and re-encrypt. */
SELECT v.Id, v.ProductId, v.VoucherCode, NULL, v.Status, v.CheckedBy,
       v.VoucherCheckDate, v.AssignedTo, v.VoucherCheckDate,
       'Status Update', ISNULL(u.FullName, '')
FROM dbo.VoucherStock_Table v
LEFT JOIN dbo.User_Table u ON u.Id = v.AssignedTo
WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)) LIKE 'DEMO%'
  AND v.VoucherCheckDate IS NOT NULL;

PRINT CONCAT('History rows created: ', @@ROWCOUNT);
GO

/* ---------- what you ended up with ---------- */
SELECT Provider = p.Name,
       Total    = COUNT(*),
       NotSet   = SUM(CASE WHEN v.Status IS NULL      THEN 1 ELSE 0 END),
       Unused   = SUM(CASE WHEN v.Status = 'Unused'   THEN 1 ELSE 0 END),
       Used     = SUM(CASE WHEN v.Status = 'Used'     THEN 1 ELSE 0 END),
       Expired  = SUM(CASE WHEN v.Status = 'Expired'  THEN 1 ELSE 0 END),
       Invalid  = SUM(CASE WHEN v.Status = 'Invalid'  THEN 1 ELSE 0 END),
       Assigned = SUM(CASE WHEN v.AssignedTo IS NOT NULL THEN 1 ELSE 0 END),
       Moved    = SUM(CASE WHEN v.IsMoved = 1 THEN 1 ELSE 0 END)
FROM dbo.VoucherStock_Table v
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = v.ProviderId
GROUP BY p.Name
ORDER BY p.Name;
GO

/* expiry windows must each give a different number, or the early-expiry
   buttons are indistinguishable */
DECLARE @T DATE = CAST(GETDATE() AS DATE);
SELECT Window_ = w.Label, Vouchers = COUNT(v.Id)
FROM (VALUES ('1 Day', 1), ('3 Days', 3), ('7 Days', 7), ('1 Month', 30)) w(Label, Days)
LEFT JOIN dbo.VoucherStock_Table v
       ON v.ExpiryDate BETWEEN @T AND DATEADD(DAY, w.Days, @T)
GROUP BY w.Label, w.Days
ORDER BY w.Days;
GO
