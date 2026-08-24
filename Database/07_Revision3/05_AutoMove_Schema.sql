/* ============================================================
   Revision 3 - overnight auto-move.

   A student no longer hands a voucher over by hand. Once they set a
   status or tick the check box, the voucher moves to the sub-admin
   at midnight that night.

   AutoMoveAfter holds that moment - the next midnight after the
   check. A sweep (Sp_VoucherStock_Table @Action = 'AutoMove') moves
   everything whose moment has passed and that has not moved yet.

   Why a dedicated column instead of reading VoucherCheckDate:
   reassigning a voucher has to put it back in the student's hands.
   If the rule were driven off the old check date, the sweep would
   snatch it away again on the very next page load. Reassign clears
   AutoMoveAfter, which restarts the clock properly.

   Why a sweep instead of a scheduled job: LocalDB has no SQL Agent.
   The sweep runs when View Data is opened, so by the time anyone
   looks, the move has already happened - which is what 'moves at
   12am' means in practice.

   Re-runnable.
   ============================================================ */
USE DSL_New;
GO

/* The filtered index below cannot be built, and the backfill below it cannot
   run, unless this is on. sqlcmd defaults it off. */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.VoucherStock_Table', 'AutoMoveAfter') IS NULL
BEGIN
    ALTER TABLE dbo.VoucherStock_Table ADD AutoMoveAfter DATETIME NULL;
    PRINT 'Added VoucherStock_Table.AutoMoveAfter';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VoucherStock_AutoMove')
    CREATE NONCLUSTERED INDEX IX_VoucherStock_AutoMove
        ON dbo.VoucherStock_Table (IsMoved, AutoMoveAfter)
        WHERE AutoMoveAfter IS NOT NULL;
GO

/* ---------- backfill ----------
   Vouchers already checked but still sitting with a student get the
   midnight after their check date, so existing data behaves the same
   way as anything checked from now on.

   AssignedTo IS NOT NULL matters: a move hands a voucher FROM a
   student TO the sub-admin. A voucher nobody is holding has no such
   journey to make, and dropping it into the done list would be
   meaningless. Without this clause the backfill stamps 227 rows, of
   which 219 belong to no one. */
UPDATE dbo.VoucherStock_Table
   SET AutoMoveAfter = DATEADD(DAY, 1, CAST(VoucherCheckDate AS DATE))
 WHERE AutoMoveAfter IS NULL
   AND IsMoved = 0
   AND AssignedTo IS NOT NULL
   AND VoucherCheckDate IS NOT NULL
   AND Status IS NOT NULL;

PRINT CONCAT('Backfilled AutoMoveAfter on ', @@ROWCOUNT, ' voucher(s)');
GO

/* an unassigned voucher must never carry the stamp - clears anything
   an earlier run of this script may have marked */
UPDATE dbo.VoucherStock_Table
   SET AutoMoveAfter = NULL
 WHERE AutoMoveAfter IS NOT NULL
   AND AssignedTo IS NULL
   AND IsMoved = 0;

PRINT CONCAT('Cleared stamp from ', @@ROWCOUNT, ' unassigned voucher(s)');
GO

SELECT PendingAssigned = COUNT(*)
FROM dbo.VoucherStock_Table
WHERE IsMoved = 0 AND AssignedTo IS NOT NULL
  AND AutoMoveAfter IS NOT NULL AND AutoMoveAfter <= GETDATE();
GO
