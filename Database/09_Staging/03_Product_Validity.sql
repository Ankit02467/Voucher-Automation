/* ============================================================
   Validity on the four products that carry it on the development
   database.

   This exists only so a freshly built database and the
   development one stop disagreeing. The 365s are an accident of
   history, not a decision:

   05_ViewData/02_Seed_Products.sql cross joined Foundation,
   Associate and Professional - all at 365 days - onto every
   provider. 07_Revision3/01_Products.sql later replaced that with
   the real per-provider lists, but it inserts new products as
   (ProviderId, Name, Status) with no validity, and it only flips
   Status on ones that already exist. So the rows whose names
   happened to appear in both lists kept their 365, and everything
   07_Revision3 created fresh has NULL.

   That leaves exactly four: AWS's three tiers, which the real
   list happens to use the same names for, and Microsoft
   Professional. LanguageCERT's three keep theirs too, and are
   handled in 02_LanguageCERT_Products.sql.

   ValidityDays is display-and-edit only - Manage Product shows it
   and writes it, and no procedure computes an expiry date from
   it - so none of this changes behaviour. It is here so that
   diffing the two databases comes back clean, and so that whoever
   sets real validities later starts from the same place in both.

   Only ever fills a NULL. It will not overwrite a validity
   somebody has deliberately set.
   ============================================================ */
USE DSL_New;
GO

SET QUOTED_IDENTIFIER ON;
GO

UPDATE pr
   SET pr.ValidityDays = 365,
       pr.ModifiedDate = GETDATE()
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
INNER JOIN (VALUES
    ('AWS',       'Foundation'),
    ('AWS',       'Associate'),
    ('AWS',       'Professional'),
    ('Microsoft', 'Professional')
) AS v(ProviderName, ProductName)
        ON v.ProviderName = p.Name AND v.ProductName = pr.Name
WHERE pr.ValidityDays IS NULL;

PRINT CONCAT('  product validities set: ', @@ROWCOUNT);
GO

SELECT Provider = p.Name, Product = pr.Name, pr.ValidityDays, pr.Status
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
WHERE pr.ValidityDays IS NOT NULL
ORDER BY p.Id, pr.Id;
GO
