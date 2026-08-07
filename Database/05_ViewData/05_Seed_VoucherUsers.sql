/* ============================================================
   Four test users, one per Voucher role.

   User_Table.Type     -> UserTypeMaster.Id (the role)
   User_Table.UserType -> UserTypeMaster.TypeId (the module, 4 = Voucher)

   Passwords are stored Base64 encoded, matching the existing rows
   (Sp_User_Table compares the encoded value directly).
       Voucher@123  ->  Vm91Y2hlckAxMjM=
   No existing user is modified.
   ============================================================ */
USE DSL_New;
GO

INSERT INTO dbo.User_Table (FullName, FName, LName, Email, Contact1, [Password],
                            [Type], UserType, Status, ActDate)
SELECT v.FullName, v.FName, v.LName, v.Email, v.Contact1,
       'Vm91Y2hlckAxMjM=',            -- Voucher@123
       v.RoleId, 4, 1, GETDATE()
FROM (VALUES
    ('Voucher Admin',     'Voucher', 'Admin',    'voucher.admin@dsucceedlearners.com',    '9000000010', 10),
    ('Voucher Sub Admin', 'Voucher', 'SubAdmin', 'voucher.subadmin@dsucceedlearners.com', '9000000011', 11),
    ('Voucher Team',      'Voucher', 'Team',     'voucher.team@dsucceedlearners.com',     '9000000012', 12),
    ('Voucher Student',   'Voucher', 'Student',  'voucher.student@dsucceedlearners.com',  '9000000013', 13)
) AS v(FullName, FName, LName, Email, Contact1, RoleId)
WHERE NOT EXISTS (SELECT 1 FROM dbo.User_Table u WHERE u.Email = v.Email);
GO

SELECT u.Id, u.FullName, u.Email, RoleId = u.[Type],
       Role = t.UserTypeName, Module = t.TypeName, u.Status
FROM dbo.User_Table u
INNER JOIN dbo.UserTypeMaster t ON t.Id = u.[Type]
WHERE t.TypeId = 4
ORDER BY u.[Type];
GO
