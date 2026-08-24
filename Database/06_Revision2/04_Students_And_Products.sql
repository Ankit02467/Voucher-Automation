/* ============================================================
   1. Four student users for the Voucher module.
   2. Retire the legacy single product per provider
      (AWS SAA-C03 Voucher, Microsoft AZ-900 Voucher, ...) so the
      upload modal and filters only offer Foundation / Associate /
      Professional.

   The legacy products are set Inactive rather than deleted -
   existing vouchers still point at them, so deleting would break
   the foreign key and lose which product those vouchers belong to.
   ============================================================ */
USE DSL_New;
GO

/* ---------- 1. student users ---------- */
INSERT INTO dbo.User_Table (FullName, FName, LName, Email, Contact1, [Password],
                            [Type], UserType, Status, ActDate)
SELECT v.FullName, v.FName, v.LName, v.Email, v.Contact1,
       'Vm91Y2hlckAxMjM=',            -- Voucher@123
       13, 4, 1, GETDATE()            -- 13 = Voucher Student
FROM (VALUES
    ('Aarav Sharma', 'Aarav', 'Sharma', 'student1@dsucceedlearners.com', '9000000021'),
    ('Diya Patel',   'Diya',  'Patel',  'student2@dsucceedlearners.com', '9000000022'),
    ('Kabir Singh',  'Kabir', 'Singh',  'student3@dsucceedlearners.com', '9000000023'),
    ('Meera Nair',   'Meera', 'Nair',   'student4@dsucceedlearners.com', '9000000024')
) AS v(FullName, FName, LName, Email, Contact1)
WHERE NOT EXISTS (SELECT 1 FROM dbo.User_Table u WHERE u.Email = v.Email);
GO

/* ---------- 2. retire the legacy products ---------- */
UPDATE dbo.VoucherProduct_Table
   SET Status = 'I', ModifiedDate = GETDATE()
 WHERE Name NOT IN ('Foundation', 'Associate', 'Professional');
GO

SELECT u.Id, u.FullName, u.Email, Role = t.UserTypeName
FROM dbo.User_Table u
INNER JOIN dbo.UserTypeMaster t ON t.Id = u.[Type]
WHERE t.TypeId = 4 AND t.UserTypeName = 'Voucher Student'
ORDER BY u.Id;
GO

SELECT p.Name AS Provider, pr.Name AS Product, pr.Status
FROM dbo.VoucherProduct_Table pr
INNER JOIN dbo.VoucherProvider_Table p ON p.Id = pr.ProviderId
WHERE p.Id = 1
ORDER BY pr.Status, pr.Name;
GO
