/* ============================================================
   The order products sit in under their provider.

   Until now that order was alphabetical, which is what the
   ORDER BY happened to say rather than anything anybody decided:
   AWS reads Associate, Foundation, Professional, and the ladder
   it names runs the other way round.

   SortOrder is the decision, written down. Voucher Status lets an
   admin drag a product up or down and saves the result here; the
   sidebar, Manage Product and every product dropdown read the
   same column, so the list reads one way everywhere.

   NULL is the whole of the compatibility story. A product nobody
   has dragged sorts after every product somebody has, and then
   alphabetically among its own kind - which is exactly where it
   sat before this column existed. So running this on a live
   database changes nothing at all until somebody drags something.

   Re-runnable.

   The column is also in 01_Tables/02_VoucherProduct_Table.sql, so
   a database built from scratch gets it there and this file finds
   nothing to do. This is for the ones already standing.

   AFTERWARDS, re-run these two - they read and write the column,
   and both are edited in place rather than copied here, so that
   there is one copy of each proc to keep right:

     sqlcmd -I ... -i Database/02_StoredProcedures/02_Sp_VoucherProduct_Table.sql
     sqlcmd -I ... -i Database/07_Revision3/02_Sp_VoucherProvider.sql

   -I matters. See trap 7 in CLAUDE.md.
   ============================================================ */
USE DSL_New;
GO

SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.VoucherProduct_Table')
                  AND name = 'SortOrder')
BEGIN
    ALTER TABLE dbo.VoucherProduct_Table ADD SortOrder INT NULL;
    PRINT '  VoucherProduct_Table.SortOrder added';
END
ELSE
    PRINT '  VoucherProduct_Table.SortOrder already there';
GO

/* ---------- verify ----------
   Every product, in the order the screens will now show it. With
   nothing dragged yet this is the alphabetical list it has always
   been, which is the point. */
SELECT Provider = p.Name,
       Product  = pr.Name,
       pr.SortOrder,
       pr.Status
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
WHERE pr.Status = 'A'
ORDER BY p.Name, ISNULL(pr.SortOrder, 2147483647), pr.Name;
GO
