/* ============================================================
   Revision - the admin moves vouchers to another product.

   A batch uploaded against the wrong product - AWS Foundation codes
   that belonged to Associate - is put right from View Data. The
   Product box in the admin's Edit dialog moves one voucher, and
   Change Product moves the ticked ones of the screen together.

   One change, inside the proc that already exists:

   Sp_VoucherStock_Table @Action = 'ChangeProduct' takes @Ids (one
   id, or a comma-separated batch), @ProductId (where they go),
   @ProviderId and @AddedBy. It moves vouchers only onto a live
   product of their own provider, never writes ProviderId, and
   leaves everything else on the voucher as it was. Every voucher
   moved gets a 'Product Change' history row carrying the product
   it came from, and SelectVoucherHistory returns that product's
   name as ProductName so View History can say so.

   The performance counts read only 'Status Update' and 'Voucher
   Checked', so the new row is nobody's work. They do group on the
   voucher's live product, though, so a moved voucher's past checks
   count under its new product from then on - which is the point of
   correcting it.

   ------------------------------------------------------------
   THERE IS NO SCHEMA CHANGE HERE.

   The proc is edited IN PLACE - trap 1 is what a second copy
   costs. This file records the change and checks the result.
   Re-run the proc, and mind trap 7:

     sqlcmd -I -i Database/07_Revision3/03_Sp_VoucherStock.sql

   Order against the site does not matter. Until the proc is run
   the page finds no ChangeProduct - an older proc returns no
   result set - and says the database has not been updated rather
   than reporting a move that never happened. Nothing else the
   site sends has changed.
   ============================================================ */
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

/* ---- 1. the proc was created with QUOTED_IDENTIFIER on (trap 7) ---- */
SELECT Proc_ = o.name, QuotedIdentifier = m.uses_quoted_identifier
FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id
WHERE o.name = 'Sp_VoucherStock_Table';                                   -- 1

/* ---- 2. the new action is there ---- */
SELECT HasChangeProduct =
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.Sp_VoucherStock_Table'))
                 LIKE '%''ChangeProduct''%' THEN 1 ELSE 0 END;               -- 1

/* ---- 3. it refuses rather than guesses: no ids, no product ---- */
EXEC dbo.Sp_VoucherStock_Table @Action = 'ChangeProduct';                   -- Moved 0, Refused 1
GO
