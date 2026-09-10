/* ============================================================
   Revision - "Open" replaces "All", and a lapsed voucher belongs
   to Expired and to nothing else.

   The team read "Not set 50" beside "Expired 13" and did the
   subtraction in their heads every morning: thirteen of those
   fifty were past saving and still counted as work waiting.

   So the buckets that mean "still to do" stop counting what has
   already run out:

     Open    = not Used, not Invalid, not past its date
               (this is what the All pill used to be)
     Not Set = Status IS NULL,     and not past its date
     Unused  = Status = 'Unused',  and not past its date
     Expired = past its date, whatever anybody typed against it

   Used and Invalid are untouched. Those are outcomes somebody
   recorded rather than work waiting, and a used voucher that
   later runs out is still used.

   Nothing becomes unreachable. Open, Used, Invalid and Expired
   between them are every voucher, so the thirteen that leave
   "Not set" arrive under "Expired" the same instant - which is
   why the Expired card was added to the dashboard in the same
   change. The verification at the bottom asserts exactly that.

   Written as an exclusion ("not Used, not Invalid, not lapsed")
   rather than an inclusion ("Unused or Not Set") so that a row
   carrying the word 'Expired' in the status column with a date
   still ahead of it stays in Open, instead of falling out of
   every bucket there is.

   ------------------------------------------------------------
   THERE IS NO SCHEMA CHANGE HERE.

   The rule lives in two procs, both edited IN PLACE - trap 1 is
   what a second copy costs. This file only records the decision
   and checks the result. Re-run both procs, and mind trap 7:

     sqlcmd -S <server> -d <db> -I -i Database\07_Revision3\02_Sp_VoucherProvider.sql
     sqlcmd -S <server> -d <db> -I -i Database\07_Revision3\03_Sp_VoucherStock.sql

   voucher-data.aspx.cs carries the same rule a third time, in
   MatchesRow, because that screen filters its statuses in C# so
   its cards can see past whichever button is pressed. All three
   have to agree or a card promises rows the list will not show.
   ============================================================ */
USE DSL_New;
GO

SET QUOTED_IDENTIFIER ON;
GO

/* ---------- verify 1: the procs carry the rule ---------- */
SELECT Proc_Name          = o.name,
       Quoted_Identifier  = m.uses_quoted_identifier,   -- must be 1, trap 7
       Knows_Open         = CASE WHEN m.definition LIKE '%''Open''%' THEN 1 ELSE 0 END
FROM sys.sql_modules m
INNER JOIN sys.objects o ON o.object_id = m.object_id
WHERE o.name IN ('Sp_VoucherProvider_Table', 'Sp_VoucherStock_Table')
ORDER BY o.name;
GO

/* ---------- verify 2: the figures ----------
   Open + Used + Invalid + Expired is every voucher; the overlap
   is only where a used or written-off one has also run out. */
DECLARE @Today DATE = CAST(GETDATE() AS DATE);

SELECT Total    = COUNT(*),
       [Open]   = SUM(CASE WHEN ISNULL(Status, '') NOT IN ('Used', 'Invalid')
                            AND (ExpiryDate IS NULL OR ExpiryDate >= @Today)
                           THEN 1 ELSE 0 END),
       Used     = SUM(CASE WHEN Status = 'Used'    THEN 1 ELSE 0 END),
       Invalid  = SUM(CASE WHEN Status = 'Invalid' THEN 1 ELSE 0 END),
       Expired  = SUM(CASE WHEN ExpiryDate IS NOT NULL AND ExpiryDate < @Today
                           THEN 1 ELSE 0 END),
       NotSet   = SUM(CASE WHEN Status IS NULL
                            AND (ExpiryDate IS NULL OR ExpiryDate >= @Today)
                           THEN 1 ELSE 0 END),
       Unused   = SUM(CASE WHEN Status = 'Unused'
                            AND (ExpiryDate IS NULL OR ExpiryDate >= @Today)
                           THEN 1 ELSE 0 END)
FROM dbo.VoucherStock_Table;
GO

/* ---------- verify 3: nothing is unreachable ----------
   Must return zero. A voucher that is in none of Open, Used,
   Invalid or Expired is one the screens can no longer show at
   all, which is the only way this change could lose anything. */
DECLARE @T DATE = CAST(GETDATE() AS DATE);

SELECT Stranded = COUNT(*)
FROM dbo.VoucherStock_Table v
WHERE NOT (ISNULL(v.Status, '') NOT IN ('Used', 'Invalid')
           AND (v.ExpiryDate IS NULL OR v.ExpiryDate >= @T))   -- not Open
  AND ISNULL(v.Status, '') <> 'Used'
  AND ISNULL(v.Status, '') <> 'Invalid'
  AND NOT (v.ExpiryDate IS NOT NULL AND v.ExpiryDate < @T);    -- not Expired
GO
