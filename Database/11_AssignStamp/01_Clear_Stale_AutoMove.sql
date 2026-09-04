/* ============================================================
   Clears AutoMoveAfter stamps that predate the hold they sit on.

   The companion to the one-line change in
   07_Revision3/03_Sp_VoucherStock.sql, which makes Assign set
   AutoMoveAfter back to NULL the way Reassign always has. That
   stops new ones; this clears the ones already there.

   How they got there
   ------------------
   A sub-admin can set a status on a voucher nobody holds. That
   stamps AutoMoveAfter with the coming midnight, and the sweep
   ignores it - AutoMove only moves vouchers with a student on
   them. Assign then put a student on it without clearing the
   stamp, so the very next View Data page load handed the voucher
   straight to the done list. The student never saw it, and on
   their own screen it counted as work somebody else had done.

   What this clears
   ----------------
   Held vouchers whose stamp is no later than the moment they were
   assigned. A stamp made during the hold is always later than the
   assignment, so this cannot touch a voucher the student has
   genuinely checked and which is due to move tonight.

   Re-runnable: after it has run once there is nothing left to
   match, and it reports how many it cleared.
   ============================================================ */
USE DSL_New;
GO

SET QUOTED_IDENTIFIER ON;
GO

UPDATE dbo.VoucherStock_Table
   SET AutoMoveAfter = NULL,
       ModifiedDate  = GETDATE()
 WHERE IsMoved = 0
   AND AssignedTo    IS NOT NULL
   AND AssignedDate  IS NOT NULL
   AND AutoMoveAfter IS NOT NULL
   AND AutoMoveAfter <= AssignedDate;
GO

PRINT 'Stale AutoMoveAfter stamps cleared';
GO
