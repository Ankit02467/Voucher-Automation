/* ============================================================
   Revision - uploads that scale, a View Data grid that decrypts
   one page, and a dealer's name in the topbar search.

   Three changes, all inside the two procs that already exist:

   1. BulkInsert stopped comparing every pasted code with every
      other. The skipped-codes list and the dealer attach both
      matched HASHBYTES(code) against a table variable with no
      index on the hash, so the work grew with the square of the
      paste: 5,000 lines took 19 s and 20,000 took four minutes,
      and a lakh would have run for hours against a 30 second
      command timeout. The hash is worked out once per code now,
      into an indexed column, and every match is a seek - 5,000
      lines in about 2 s, 20,000 in about 8 s. Same rows in, same
      rows skipped, same dealers attached.

   2. Sp_VoucherStock_Table @Action = 'SelectKeys' returns the
      rows Select returns, in the same order, without anything
      that has to be decrypted (codes, names, dealers, remarks).
      View Data counts, filters, sorts and pages on it, and asks
      Select for the full rows of the one page on screen, through
      the new @Ids filter. Its FROM and WHERE are Select's and
      must stay so.

   3. The topbar box takes a dealer's name for the admin and the
      team. Sp_VoucherStock_Table @Action = 'SearchMatch' says
      whether a term is a code or a dealer, and
      Sp_VoucherProvider_Table takes @DealerName on SelectSummary
      and SelectDashboardTotals, so Voucher Status can list only
      the providers holding that dealer's vouchers.

   The 2 Months expiry window is the site alone - both procs
   already took any number of days.

   ------------------------------------------------------------
   THERE IS NO SCHEMA CHANGE HERE.

   Both procs are edited IN PLACE - trap 1 is what a second copy
   costs. This file records the change and checks the result.
   Re-run both, TOGETHER, and mind trap 7:

     sqlcmd -I -i Database/07_Revision3/02_Sp_VoucherProvider.sql
     sqlcmd -I -i Database/07_Revision3/03_Sp_VoucherStock.sql

   Order against the site does not matter. The site sends the
   new parameter only when a dealer is being searched, falls back
   to the full fetch if SelectKeys returns nothing, and treats a
   SearchMatch that returns nothing as "search codes", so it runs
   on the old procs exactly as it did. A dealer link that does
   reach the old provider proc is refused with msg 8145, and the
   page drops the search rather than failing. The old site never
   sends anything the new procs changed.
   ============================================================ */
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

/* ---- 1. both procs were created with QUOTED_IDENTIFIER on (trap 7) ---- */
SELECT Proc_ = o.name, QuotedIdentifier = m.uses_quoted_identifier
FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id
WHERE o.name IN ('Sp_VoucherStock_Table', 'Sp_VoucherProvider_Table');   -- both 1

/* ---- 2. the keys-only fetch covers every row the full one does ---- */
CREATE TABLE #k (Id INT, ProviderId INT, ProviderName NVARCHAR(300), ProductId INT, ProductName NVARCHAR(300),
                 ExpiryDate DATE, AddedByName NVARCHAR(300), DealerCount INT, Status NVARCHAR(20),
                 UsedDate DATE, VoucherCheckDate DATETIME, CheckedBy NVARCHAR(100), ExamDate DATE,
                 ExamMode NVARCHAR(50), AssignedTo INT, AssignedToName NVARCHAR(300), IsMoved BIT,
                 MovedDate DATETIME, AutoMoveAfter DATETIME, AddedDate DATETIME);
INSERT #k EXEC dbo.Sp_VoucherStock_Table @Action = 'SelectKeys';
SELECT KeysRows  = (SELECT COUNT(*) FROM #k),
       GridRows  = (SELECT COUNT(*) FROM dbo.VoucherStock_Table v
                    JOIN dbo.VoucherProvider_Table p ON p.Id = v.ProviderId
                    JOIN dbo.VoucherProduct_Table pr ON pr.Id = v.ProductId);   -- equal
DROP TABLE #k;

/* ---- 3. the search check answers, and a dealer nobody has is nobody ---- */
EXEC dbo.Sp_VoucherStock_Table @Action = 'SearchMatch',
     @VoucherCode = N'zz no such code', @DealerName = N'zz no such dealer';     -- 0, 0
EXEC dbo.Sp_VoucherProvider_Table @Action = 'SelectDashboardTotals',
     @DealerName = N'zz no such dealer';                                          -- TotalVoucher 0
GO
