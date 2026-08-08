/* ============================================================
   Undoes 01_Dummy_Vouchers.sql.

   Everything that script creates carries a code starting "DEMO", so
   this removes exactly that and nothing else. Vouchers you uploaded
   yourself are untouched.

   Children first - VoucherHistory_Table and VoucherDealer_Table both
   have a foreign key to VoucherStock_Table.

   Re-runnable.
   ============================================================ */
USE DSL_New;
GO

SET NOCOUNT ON;

DELETE h FROM dbo.VoucherHistory_Table h
 INNER JOIN dbo.VoucherStock_Table v ON v.Id = h.VoucherId
 WHERE v.VoucherCode LIKE 'DEMO%';
PRINT CONCAT('History rows removed: ', @@ROWCOUNT);

DELETE d FROM dbo.VoucherDealer_Table d
 INNER JOIN dbo.VoucherStock_Table v ON v.Id = d.VoucherId
 WHERE v.VoucherCode LIKE 'DEMO%';
PRINT CONCAT('Dealer rows removed: ', @@ROWCOUNT);

DELETE FROM dbo.VoucherStock_Table WHERE VoucherCode LIKE 'DEMO%';
PRINT CONCAT('Vouchers removed: ', @@ROWCOUNT);
GO

SELECT RemainingDemoVouchers = COUNT(*)
FROM dbo.VoucherStock_Table WHERE VoucherCode LIKE 'DEMO%';
GO
