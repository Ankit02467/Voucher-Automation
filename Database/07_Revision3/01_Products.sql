/* ============================================================
   Revision 3 - product lists per provider.

   The wanted list below is the single source of truth for the
   four providers named in it. Anything active under those
   providers that is NOT in the list is retired (Status = 'I'),
   never deleted - existing vouchers still point at those rows and
   deleting would break FK_VoucherStock_Product and lose which
   product those vouchers belonged to.

   LanguageCERT is deliberately absent: no product list was given
   for it, so its rows are left exactly as they are.

   Re-runnable.
   ============================================================ */
USE DSL_New;
GO

DECLARE @Wanted TABLE
(
    ProviderName NVARCHAR(150) NOT NULL,
    ProductName  NVARCHAR(150) NOT NULL,
    PRIMARY KEY (ProviderName, ProductName)
);

INSERT INTO @Wanted (ProviderName, ProductName) VALUES
    ('AWS',       'Foundation'),
    ('AWS',       'Associate'),
    ('AWS',       'Professional'),

    ('Microsoft', 'Professional'),
    ('Microsoft', 'Fundamental'),
    ('Microsoft', 'Microsoft USA'),
    ('Microsoft', 'Microsoft Bangladesh'),

    ('PTE',       'PTE India'),
    ('PTE',       'PTE Nepal'),
    ('PTE',       'PTE Bangladesh'),
    ('PTE',       'PTE Sri Lanka'),
    ('PTE',       'PTE Bhutan'),

    ('ETS',       'TOEFL India'),
    ('ETS',       'TOEFL Nepal'),
    ('ETS',       'TOEFL Bangladesh'),
    ('ETS',       'GRE International');

/* ---------- 1. add the ones that do not exist yet ---------- */
INSERT INTO dbo.VoucherProduct_Table (ProviderId, Name, Status)
SELECT p.Id, w.ProductName, 'A'
FROM @Wanted w
INNER JOIN dbo.VoucherProvider_Table p ON p.Name = w.ProviderName
WHERE NOT EXISTS (SELECT 1 FROM dbo.VoucherProduct_Table pr
                   WHERE pr.ProviderId = p.Id AND pr.Name = w.ProductName);

PRINT CONCAT('Products added: ', @@ROWCOUNT);

/* ---------- 2. make sure every wanted product is active ---------- */
UPDATE pr
   SET Status = 'A', ModifiedDate = GETDATE()
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
INNER JOIN @Wanted w ON w.ProviderName = p.Name AND w.ProductName = pr.Name
WHERE pr.Status <> 'A';

PRINT CONCAT('Products re-activated: ', @@ROWCOUNT);

/* ---------- 3. retire everything else under those four ---------- */
UPDATE pr
   SET Status = 'I', ModifiedDate = GETDATE()
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
WHERE p.Name IN ('AWS', 'Microsoft', 'PTE', 'ETS')
  AND pr.Status = 'A'
  AND NOT EXISTS (SELECT 1 FROM @Wanted w
                   WHERE w.ProviderName = p.Name AND w.ProductName = pr.Name);

PRINT CONCAT('Products retired: ', @@ROWCOUNT);
GO

/* ---------- verify ---------- */
SELECT Provider = p.Name,
       Product  = pr.Name,
       pr.Status,
       Vouchers = (SELECT COUNT(*) FROM dbo.VoucherStock_Table v WHERE v.ProductId = pr.Id)
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
ORDER BY p.Id, pr.Status, pr.Name;
GO

/* no voucher may end up orphaned - this must return zero rows */
SELECT Orphaned = COUNT(*)
FROM dbo.VoucherStock_Table v
WHERE NOT EXISTS (SELECT 1 FROM dbo.VoucherProduct_Table pr WHERE pr.Id = v.ProductId);
GO
