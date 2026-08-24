/* ============================================================
   The four student accounts, and only those.

   *** Test logins. Not for a production database. ***

   These four plus the four role accounts in
   05_ViewData/05_Seed_VoucherUsers.sql all carry the same
   password, Voucher@123, stored Base64 as Vm91Y2hlckAxMjM=
   because that is how the existing site stores passwords -
   Sp_User_Table compares the encoded string directly. That
   password is in these comments, in CLAUDE.md and in this
   repository's git history, so it is not a secret from anyone who
   can reach the site. Deploy-VoucherModule.ps1 only runs this
   under -WithTestUsers, and DEPLOYMENT.md section 3 says not to.

   ------------------------------------------------------------
   Why this file exists at all

   The same four students are already seeded by
   06_Revision2/04_Students_And_Products.sql - but that script has
   a second half:

       UPDATE dbo.VoucherProduct_Table
          SET Status = 'I'
        WHERE Name NOT IN ('Foundation', 'Associate', 'Professional');

   which retires every product whose name is not one of those
   three. Against the real catalogue that is 13 of the 19 -
   every Microsoft, PTE and ETS product 07_Revision3/01 creates.
   It made sense when the catalogue *was* those three tiers; it
   does not now.

   So the student half is lifted out here, byte for byte, and the
   product half is left where it is. Values match the development
   database exactly, contact numbers included.

   Re-runnable, and it never touches a user who already exists.
   ============================================================ */
USE DSL_New;
GO

SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO dbo.User_Table (FullName, FName, LName, Email, Contact1, [Password],
                            [Type], UserType, Status, ActDate)
SELECT v.FullName, v.FName, v.LName, v.Email, v.Contact1,
       'Vm91Y2hlckAxMjM=',            -- Voucher@123
       13, 4, 1, GETDATE()            -- 13 = Voucher Student, 4 = the Voucher module
FROM (VALUES
    ('Aarav Sharma', 'Aarav', 'Sharma', 'student1@dsucceedlearners.com', '9000000021'),
    ('Diya Patel',   'Diya',  'Patel',  'student2@dsucceedlearners.com', '9000000022'),
    ('Kabir Singh',  'Kabir', 'Singh',  'student3@dsucceedlearners.com', '9000000023'),
    ('Meera Nair',   'Meera', 'Nair',   'student4@dsucceedlearners.com', '9000000024')
) AS v(FullName, FName, LName, Email, Contact1)
WHERE NOT EXISTS (SELECT 1 FROM dbo.User_Table u WHERE u.Email = v.Email);

PRINT CONCAT('  student accounts added: ', @@ROWCOUNT);
GO

SELECT u.Id, u.FullName, u.Email, Role = t.UserTypeName, u.Status
FROM dbo.User_Table u
INNER JOIN dbo.UserTypeMaster t ON t.Id = u.[Type]
WHERE t.TypeId = 4
ORDER BY u.[Type], u.Id;
GO
