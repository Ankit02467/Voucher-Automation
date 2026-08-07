/* ============================================================
   Product tiers per provider - these are the buttons shown in the
   "Add vouchers" upload modal. Demo data; safe to re-run.
   ============================================================ */
USE DSL_New;
GO

INSERT INTO dbo.VoucherProduct_Table (ProviderId, Name, ValidityDays, Status)
SELECT p.Id, v.ProductName, v.ValidityDays, 'A'
FROM dbo.VoucherProvider_Table p
CROSS JOIN (VALUES
    ('Foundation',   365),
    ('Associate',    365),
    ('Professional', 365)
) AS v(ProductName, ValidityDays)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.VoucherProduct_Table pr
    WHERE pr.ProviderId = p.Id AND pr.Name = v.ProductName);
GO

SELECT p.Name AS Provider, pr.Id, pr.Name AS Product
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
ORDER BY p.Id, pr.Id;
GO
