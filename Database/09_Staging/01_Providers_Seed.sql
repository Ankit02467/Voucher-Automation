/* ============================================================
   The five real providers.

   Nothing in the DEPLOYMENT.md run list creates these. The only
   script that does is 04_Updates/02_Reseed_VoucherStatus_Demo.sql,
   which opens by emptying all three voucher tables and is on the
   never-run-on-production list. So a database built by following
   the run list ends up with no providers at all, and
   07_Revision3/01_Products.sql - which joins products to providers
   by name - silently adds nothing.

   This file fills that gap: the same five rows, without the deletes.
   Values are taken from the local DSL_New, so a fresh database and
   the development one agree.

   *** The ids are pinned deliberately. ***

   Helpers/ProviderBrand.cs colours each tile with
   Palette[(id - 1) % 8], so the id IS the colour:

       1 AWS           orange
       2 Microsoft     blue
       3 PTE           violet
       4 ETS           red
       5 LanguageCERT  green

   Let these identities fall where they may and staging draws the
   same providers in different colours from every other environment.
   Logo files are matched on the name instead - assets/img/providers
   holds aws.svg, microsoft.svg, pte.svg, ets.svg, languagecert.svg -
   so the names must stay exact too.

   Re-runnable, and it never touches a provider that already exists.
   ============================================================ */
USE DSL_New;
GO

SET QUOTED_IDENTIFIER ON;
GO

/* IDENTITY_INSERT so the ids above are the ids that land. It is only
   valid while the wanted id is genuinely free; on a table that already
   has providers this inserts nothing and leaves them alone. */
SET IDENTITY_INSERT dbo.VoucherProvider_Table ON;

INSERT INTO dbo.VoucherProvider_Table
    (Id, Name, Category, ContactPerson, ContactEmail, Status, AddedDate)
SELECT v.Id, v.Name, v.Category, v.ContactPerson, v.ContactEmail, 'A', GETDATE()
FROM (VALUES
    (1, N'AWS',          N'IT',       N'Karan Mehta', N'karan@aws.com'),
    (2, N'Microsoft',    N'IT',       N'Neha Gupta',  N'neha@microsoft.com'),
    (3, N'PTE',          N'Language', N'Priya Singh', N'priya@pearsonpte.com'),
    (4, N'ETS',          N'Language', N'Amit Verma',  N'amit@ets.org'),
    (5, N'LanguageCERT', N'Language', N'Rahul Sharma',N'rahul@languagecert.com')
) AS v(Id, Name, Category, ContactPerson, ContactEmail)
WHERE NOT EXISTS (SELECT 1 FROM dbo.VoucherProvider_Table p WHERE p.Id   = v.Id)
  AND NOT EXISTS (SELECT 1 FROM dbo.VoucherProvider_Table p WHERE p.Name = v.Name);

PRINT CONCAT('  providers added: ', @@ROWCOUNT);

SET IDENTITY_INSERT dbo.VoucherProvider_Table OFF;
GO

/* Identity left below the pinned rows would hand the next
   Add Provider an id that is already taken. */
DECLARE @Max INT = (SELECT ISNULL(MAX(Id), 0) FROM dbo.VoucherProvider_Table);
DBCC CHECKIDENT ('dbo.VoucherProvider_Table', RESEED, @Max) WITH NO_INFOMSGS;
GO

SELECT Id, Name, Category, Status FROM dbo.VoucherProvider_Table ORDER BY Id;
GO
