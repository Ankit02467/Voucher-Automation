/* ============================================================
   Re-seed the voucher module so the Voucher Status screen shows the
   providers / categories / counts from the approved design.

   NOTE: this CLEARS the earlier demo seed (Pearson VUE, Prometric,
   IELTS - IDP, PTE Academic, AWS Training). Those rows were sample
   data created with the module - no business data is affected, and
   the website's own Voucher_Table / sp_Voucher_Table are untouched.
   ============================================================ */
USE DSL_New;
GO

DELETE FROM dbo.VoucherStock_Table;
DELETE FROM dbo.VoucherProduct_Table;
DELETE FROM dbo.VoucherProvider_Table;
DBCC CHECKIDENT ('dbo.VoucherStock_Table',    RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.VoucherProduct_Table',  RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.VoucherProvider_Table', RESEED, 0) WITH NO_INFOMSGS;
GO

/* ---------- providers (order matches the design) ---------- */
INSERT INTO dbo.VoucherProvider_Table (Name, Category, ContactPerson, ContactEmail, Status)
VALUES ('AWS',          'IT',       'Karan Mehta', 'karan@aws.com',          'A'),
       ('Microsoft',    'IT',       'Neha Gupta',  'neha@microsoft.com',     'A'),
       ('PTE',          'Language', 'Priya Singh', 'priya@pearsonpte.com',   'A'),
       ('ETS',          'Language', 'Amit Verma',  'amit@ets.org',           'A'),
       ('LanguageCERT', 'Language', 'Rahul Sharma','rahul@languagecert.com', 'A');
GO

/* ---------- one product per provider ---------- */
INSERT INTO dbo.VoucherProduct_Table (ProviderId, Name, ValidityDays, Status)
SELECT p.Id, v.ProductName, v.ValidityDays, 'A'
FROM (VALUES
    ('AWS',          'AWS SAA-C03 Voucher',     365),
    ('Microsoft',    'Microsoft AZ-900 Voucher',365),
    ('PTE',          'PTE Academic Voucher',    120),
    ('ETS',          'TOEFL iBT Voucher',        90),
    ('LanguageCERT', 'LanguageCERT B2 Voucher', 180)
) AS v(ProviderName, ProductName, ValidityDays)
INNER JOIN dbo.VoucherProvider_Table p ON p.Name = v.ProviderName;
GO

/* ---------- vouchers, counts per the design ---------- */
;WITH Tally AS (
    SELECT TOP (200) rn = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
    FROM sys.all_objects
),
Plan_ AS (
    SELECT * FROM (VALUES
        ('AWS',          'Used',    24), ('AWS',          'Unused', 19),
        ('AWS',          'Expiry',   5), ('AWS',          'Invalid', 2),
        ('Microsoft',    'Used',    52), ('Microsoft',    'Unused', 12),
        ('Microsoft',    'Expiry',   8), ('Microsoft',    'Invalid', 3),
        ('PTE',          'Used',    33), ('PTE',          'Unused',  7),
        ('PTE',          'Expiry',   4), ('PTE',          'Invalid', 1),
        ('ETS',          'Used',    42), ('ETS',          'Unused',  1),
        ('ETS',          'Expiry',   6), ('ETS',          'Invalid', 2),
        ('LanguageCERT', 'Used',    67), ('LanguageCERT', 'Unused', 51),
        ('LanguageCERT', 'Expiry',   9), ('LanguageCERT', 'Invalid', 4)
    ) AS x(ProviderName, Status, Qty)
)
INSERT INTO dbo.VoucherStock_Table
    (ProviderId, ProductId, VoucherCode, ExpiryDate, DealerName, SaleDate, Status, VoucherCheckDate, CheckedBy)
SELECT
    p.Id,
    pr.Id,
    UPPER(LEFT(p.Name, 3)) + '-' + LEFT(pl.Status, 2) + '-'
        + RIGHT('00000' + CAST(p.Id * 100000 + ROW_NUMBER() OVER (ORDER BY p.Id, pl.Status, t.rn) AS VARCHAR(10)), 6),
    /* Expiry rows already lapsed; Unused rows fall inside the 30-day early-expiry window */
    CASE pl.Status
        WHEN 'Expiry' THEN DATEADD(DAY, -(t.rn % 40) - 1, CAST(GETDATE() AS DATE))
        WHEN 'Unused' THEN DATEADD(DAY,  (t.rn % 28) + 1, CAST(GETDATE() AS DATE))
        ELSE DATEADD(DAY, ISNULL(pr.ValidityDays, 365), CAST(GETDATE() AS DATE))
    END,
    CASE (t.rn % 4)
        WHEN 0 THEN 'Delhi Computers' WHEN 1 THEN 'Noida Infotech'
        WHEN 2 THEN 'Gurgaon Tech'    ELSE 'Study Abroad Hub'
    END,
    DATEADD(DAY, -(t.rn % 180), CAST(GETDATE() AS DATE)),
    pl.Status,
    CASE WHEN pl.Status = 'Used' THEN DATEADD(DAY, -(t.rn % 90), GETDATE()) END,
    CASE WHEN pl.Status = 'Used'
         THEN CASE (t.rn % 3) WHEN 0 THEN 'Ankit' WHEN 1 THEN 'Neha' ELSE 'Priya' END END
FROM Plan_ pl
INNER JOIN dbo.VoucherProvider_Table p  ON p.Name = pl.ProviderName
INNER JOIN dbo.VoucherProduct_Table  pr ON pr.ProviderId = p.Id
INNER JOIN Tally t ON t.rn <= pl.Qty;
GO

SELECT p.Id, p.Name, p.Category,
       Used    = SUM(CASE WHEN v.Status = 'Used'    THEN 1 ELSE 0 END),
       Unused  = SUM(CASE WHEN v.Status = 'Unused'  THEN 1 ELSE 0 END),
       Expiry  = SUM(CASE WHEN v.Status = 'Expiry'  THEN 1 ELSE 0 END),
       Invalid = SUM(CASE WHEN v.Status = 'Invalid' THEN 1 ELSE 0 END)
FROM dbo.VoucherProvider_Table p
LEFT JOIN dbo.VoucherStock_Table v ON v.ProviderId = p.Id
GROUP BY p.Id, p.Name, p.Category
ORDER BY p.Id;
GO
