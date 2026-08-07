/* ============================================================
   Seed data - Voucher module demo rows.
   Safe to re-run: every insert is guarded by NOT EXISTS.
   ============================================================ */
USE DSL_New;
GO

/* ---- Providers ---- */
INSERT INTO dbo.VoucherProvider_Table (Name, Category, ContactPerson, ContactEmail, Status)
SELECT v.Name, v.Category, v.ContactPerson, v.ContactEmail, 'A'
FROM (VALUES
    ('Pearson VUE',   'IT Certification', 'Rahul Sharma', 'rahul@pearsonvue.com'),
    ('Prometric',     'IT Certification', 'Neha Gupta',   'neha@prometric.com'),
    ('IELTS - IDP',   'English Test',     'Amit Verma',   'amit@idp.com'),
    ('PTE Academic',  'English Test',     'Priya Singh',  'priya@pearsonpte.com'),
    ('AWS Training',  'Cloud',            'Karan Mehta',  'karan@aws.com')
) AS v(Name, Category, ContactPerson, ContactEmail)
WHERE NOT EXISTS (SELECT 1 FROM dbo.VoucherProvider_Table p WHERE p.Name = v.Name);
GO

/* ---- Products ---- */
INSERT INTO dbo.VoucherProduct_Table (ProviderId, Name, ValidityDays, Status)
SELECT p.Id, v.ProductName, v.ValidityDays, 'A'
FROM (VALUES
    ('Pearson VUE',  'CompTIA A+ Voucher',      365),
    ('Pearson VUE',  'Cisco CCNA Voucher',      180),
    ('Prometric',    'Microsoft AZ-900 Voucher',365),
    ('Prometric',    'Microsoft AZ-104 Voucher',365),
    ('IELTS - IDP',  'IELTS Academic Voucher',   90),
    ('PTE Academic', 'PTE Academic Voucher',    120),
    ('AWS Training', 'AWS SAA-C03 Voucher',     365)
) AS v(ProviderName, ProductName, ValidityDays)
INNER JOIN dbo.VoucherProvider_Table p ON p.Name = v.ProviderName
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.VoucherProduct_Table pr
    WHERE pr.ProviderId = p.Id AND pr.Name = v.ProductName);
GO

/* ---- Vouchers ---- */
INSERT INTO dbo.VoucherStock_Table
    (ProviderId, ProductId, VoucherCode, ExpiryDate, DealerName, SaleDate, Status, VoucherCheckDate, CheckedBy)
SELECT pr.ProviderId, pr.Id, v.Code,
       DATEADD(DAY, ISNULL(pr.ValidityDays, 365), CAST(v.SaleDate AS DATE)),
       v.Dealer, CAST(v.SaleDate AS DATE), v.Status,
       CASE WHEN v.CheckedBy IS NULL THEN NULL ELSE CAST(v.SaleDate AS DATETIME) END,
       v.CheckedBy
FROM (VALUES
    ('CompTIA A+ Voucher',      'PV-AP-100001', 'Delhi Computers',   '2026-01-15', 'Used',   'Ankit'),
    ('CompTIA A+ Voucher',      'PV-AP-100002', 'Delhi Computers',   '2026-02-10', 'Unused', NULL),
    ('CompTIA A+ Voucher',      'PV-AP-100003', 'Noida Infotech',    '2026-03-05', 'Unused', NULL),
    ('Cisco CCNA Voucher',      'PV-CC-200001', 'Noida Infotech',    '2026-02-20', 'Used',   'Ankit'),
    ('Cisco CCNA Voucher',      'PV-CC-200002', 'Gurgaon Tech',      '2026-04-01', 'Unused', NULL),
    ('Microsoft AZ-900 Voucher','PR-AZ-300001', 'Gurgaon Tech',      '2026-01-25', 'Used',   'Neha'),
    ('Microsoft AZ-900 Voucher','PR-AZ-300002', 'Delhi Computers',   '2026-05-11', 'Unused', NULL),
    ('Microsoft AZ-104 Voucher','PR-AZ-400001', 'Mumbai Solutions',  '2026-03-18', 'Unused', NULL),
    ('IELTS Academic Voucher',  'ID-IE-500001', 'Study Abroad Hub',  '2026-02-02', 'Used',   'Priya'),
    ('IELTS Academic Voucher',  'ID-IE-500002', 'Study Abroad Hub',  '2026-06-14', 'Unused', NULL),
    ('PTE Academic Voucher',    'PT-PA-600001', 'Global Edu',        '2026-04-22', 'Used',   'Priya'),
    ('PTE Academic Voucher',    'PT-PA-600002', 'Global Edu',        '2026-07-01', 'Unused', NULL),
    ('AWS SAA-C03 Voucher',     'AW-SA-700001', 'Cloud Partners',    '2026-05-30', 'Unused', NULL),
    ('AWS SAA-C03 Voucher',     'AW-SA-700002', 'Cloud Partners',    '2026-06-25', 'Used',   'Karan')
) AS v(ProductName, Code, Dealer, SaleDate, Status, CheckedBy)
INNER JOIN dbo.VoucherProduct_Table pr ON pr.Name = v.ProductName
WHERE NOT EXISTS (SELECT 1 FROM dbo.VoucherStock_Table s WHERE s.VoucherCode = v.Code);
GO

PRINT 'Seed data loaded';
SELECT Providers = (SELECT COUNT(*) FROM dbo.VoucherProvider_Table),
       Products  = (SELECT COUNT(*) FROM dbo.VoucherProduct_Table),
       Vouchers  = (SELECT COUNT(*) FROM dbo.VoucherStock_Table);
GO
