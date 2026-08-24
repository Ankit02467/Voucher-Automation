/* ============================================================
   LanguageCERT's three products.

   07_Revision3/01_Products.sql is the source of truth for AWS,
   Microsoft, PTE and ETS, and says so - LanguageCERT is left out
   on purpose, because no product list was ever given for it, and
   the script will not retire rows it has no list for.

   That is the right call there, but it leaves a gap here. The
   only script that ever created LanguageCERT's products is
   05_ViewData/02_Seed_Products.sql, which cross joins Foundation,
   Associate and Professional onto every provider - and it is
   demo data, so it is not in the deployment run list.

   The result is that a database built from the safe scripts has a
   LanguageCERT tile on the dashboard with nothing behind it,
   while the development database has three products under it. The
   upload modal offers no product to upload against, so the
   provider is unusable rather than merely empty.

   These are the same three rows the development database holds,
   with the same validity. Re-runnable, and it will not touch a
   product that already exists.

   If a real LanguageCERT product list ever arrives, it belongs in
   07_Revision3/01_Products.sql alongside the other four, and this
   file should go.
   ============================================================ */
USE DSL_New;
GO

SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO dbo.VoucherProduct_Table (ProviderId, Name, ValidityDays, Status)
SELECT p.Id, v.ProductName, v.ValidityDays, 'A'
FROM dbo.VoucherProvider_Table p
CROSS JOIN (VALUES
    ('Foundation',   365),
    ('Associate',    365),
    ('Professional', 365)
) AS v(ProductName, ValidityDays)
WHERE p.Name = 'LanguageCERT'
  AND NOT EXISTS (SELECT 1 FROM dbo.VoucherProduct_Table pr
                   WHERE pr.ProviderId = p.Id AND pr.Name = v.ProductName);

PRINT CONCAT('  LanguageCERT products added: ', @@ROWCOUNT);
GO

SELECT Provider = p.Name, Product = pr.Name, pr.ValidityDays, pr.Status
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
WHERE p.Name = 'LanguageCERT'
ORDER BY pr.Id;
GO
