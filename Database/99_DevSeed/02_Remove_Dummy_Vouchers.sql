/* ============================================================
   Undoes 01_Dummy_Vouchers.sql.

   Everything that script creates carries a code starting "DEMO", so
   this removes exactly that and nothing else. Vouchers you uploaded
   yourself are untouched.

   Voucher codes are encrypted (see 08_Encryption), so "DEMO%" has to
   be decrypted before it can be matched - every row is read, which is
   fine for a development table.

   Children first - VoucherHistory_Table and VoucherDealer_Table both
   have a foreign key to VoucherStock_Table.

   Re-runnable.
   ============================================================ */
USE DSL_New;
GO

/* Filtered index on AutoMoveAfter - see CLAUDE.md trap 7. */
SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'VoucherDataKey')
    OPEN SYMMETRIC KEY VoucherDataKey DECRYPTION BY CERTIFICATE VoucherDataCert;

IF NOT EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'VoucherDataKey')
BEGIN
    RAISERROR('VoucherDataKey is not open - the demo rows cannot be identified, so nothing was deleted.', 16, 1);
    RETURN;
END

DELETE h FROM dbo.VoucherHistory_Table h
 INNER JOIN dbo.VoucherStock_Table v ON v.Id = h.VoucherId
 WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)) LIKE 'DEMO%';
PRINT CONCAT('History rows removed: ', @@ROWCOUNT);

DELETE d FROM dbo.VoucherDealer_Table d
 INNER JOIN dbo.VoucherStock_Table v ON v.Id = d.VoucherId
 WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(v.VoucherCode)) LIKE 'DEMO%';
PRINT CONCAT('Dealer rows removed: ', @@ROWCOUNT);

DELETE FROM dbo.VoucherStock_Table
 WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(VoucherCode)) LIKE 'DEMO%';
PRINT CONCAT('Vouchers removed: ', @@ROWCOUNT);

SELECT RemainingDemoVouchers = COUNT(*)
FROM dbo.VoucherStock_Table
WHERE CONVERT(NVARCHAR(200), DECRYPTBYKEY(VoucherCode)) LIKE 'DEMO%';
GO
