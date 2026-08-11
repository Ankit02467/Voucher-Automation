/* ============================================================
   Column encryption for the voucher module.

   Voucher codes are the asset this module exists to hold, and
   candidate and dealer names are personal and commercial data.
   All of it sat in the database as readable text. This encrypts
   it at rest with an AES-256 symmetric key, protected by a
   certificate, protected by the database master key.

   *** BACK UP THE CERTIFICATE. ***

   The data cannot be read without VoucherDataCert's private key.
   Restore this database onto another server without also
   restoring the certificate and every voucher code is gone -
   the rows are still there, DECRYPTBYKEY just returns NULL. See
   section 8 at the bottom of this file, and DEPLOYMENT.md.

   ------------------------------------------------------------
   What is encrypted

     VoucherStock_Table    VoucherCode, CandidateName, Remarks,
                           DealerName, DealerName2
     VoucherDealer_Table   DealerName
     VoucherHistory_Table  VoucherCode

   DealerName / DealerName2 on VoucherStock_Table are dead - no
   proc reads or writes them and all 128 rows are NULL. They are
   converted anyway so no future code can put plain text there.

   What is deliberately NOT encrypted, and why

     ProviderId, ProductId, Status, and every date
         The dashboard groups by Status, the early-expiry window
         compares ExpiryDate, and the auto-move sweep has a
         filtered index on AutoMoveAfter. Encrypting any of them
         means none of that can run in SQL any more.

     CheckedBy
         Feeds the Checked By filter as a DISTINCT list and has
         its own index. Encrypting it costs a full decrypt on
         every dropdown build for a name that is already visible
         on screen to everyone who can see the row.

     User_Table - anything at all
         Shared with the public website. Thirteen USP_ procs
         read it (booking, training, ETS reports) and 34 of its
         42 rows are not voucher users. Touching it breaks the
         live site.

   ------------------------------------------------------------
   The unique constraint

   ENCRYPTBYKEY is randomised: the same voucher code encrypts to
   different bytes every time. UQ_VoucherStock_Code could not
   survive that, and it is what stops the same code being
   uploaded twice.

   VoucherCodeHash - SHA2_256 of the plain code - replaces it,
   and the duplicate checks in BulkInsert and Insert compare
   hashes instead of text.

   The hash is unsalted, so someone holding a copy of the
   database can confirm a code they already guessed. Real
   provider codes have far too much entropy for that to matter;
   short demo codes like DEMO-0001 do not. Worth knowing before
   seeding anything predictable into production.
   ============================================================ */
USE DSL_New;
GO

/* Filtered index on AutoMoveAfter - see CLAUDE.md trap 7. sqlcmd defaults
   this off, and the UPDATEs below would fail with msg 1934. */
SET QUOTED_IDENTIFIER ON;
GO

/* ---------- 1. key material ---------------------------------
   The master key is encrypted by this password AND by the service
   master key, so SQL Server can open it by itself and the app never
   has to supply a password. Change the password before production
   and record it somewhere you will still have after a disaster - it
   is the only way back in if the service master key is lost. */
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Ch4nge-Me-Before-Production!';
    PRINT '  created database master key';
END
ELSE
    PRINT '  database master key already present';
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'VoucherDataCert')
BEGIN
    CREATE CERTIFICATE VoucherDataCert
        WITH SUBJECT = 'Voucher module column encryption',
             EXPIRY_DATE = '2099-12-31';
    PRINT '  created certificate VoucherDataCert';
END
ELSE
    PRINT '  certificate VoucherDataCert already present';
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'VoucherDataKey')
BEGIN
    CREATE SYMMETRIC KEY VoucherDataKey
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE VoucherDataCert;
    PRINT '  created symmetric key VoucherDataKey';
END
ELSE
    PRINT '  symmetric key VoucherDataKey already present';
GO

/* Stays open for the rest of this session, across the GO batches below. */
OPEN SYMMETRIC KEY VoucherDataKey DECRYPTION BY CERTIFICATE VoucherDataCert;
GO

/* ---------- 2. hash column, while the codes are still readable --- */
IF COL_LENGTH('dbo.VoucherStock_Table', 'VoucherCodeHash') IS NULL
BEGIN
    ALTER TABLE dbo.VoucherStock_Table ADD VoucherCodeHash VARBINARY(32) NULL;
    PRINT '  added VoucherStock_Table.VoucherCodeHash';
END
GO

/* Only possible while VoucherCode is still text. If this file is re-run
   after the conversion the column is varbinary and the backfill is skipped -
   by then every row already has its hash. */
IF EXISTS (SELECT 1 FROM sys.columns c
           JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('dbo.VoucherStock_Table')
             AND c.name = 'VoucherCode' AND t.name = 'nvarchar')
BEGIN
    UPDATE dbo.VoucherStock_Table
       SET VoucherCodeHash = HASHBYTES('SHA2_256', VoucherCode)
     WHERE VoucherCodeHash IS NULL;

    PRINT '  hashed ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' voucher code(s)';
END
GO

/* ---------- 3. indexes that stand on VoucherCode ----------------
   Both have to go before the column can change type. The unique one is
   replaced by its hash equivalent in section 5; the covering one is
   rebuilt without VoucherCode, which is no use as ciphertext. */
/* It is a UNIQUE constraint, not a bare index, so DROP INDEX is refused -
   msg 3723. Both forms are handled in case an older database has either. */
IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_VoucherStock_Code'
             AND parent_object_id = OBJECT_ID('dbo.VoucherStock_Table'))
BEGIN
    ALTER TABLE dbo.VoucherStock_Table DROP CONSTRAINT UQ_VoucherStock_Code;
    PRINT '  dropped UQ_VoucherStock_Code (constraint)';
END
ELSE IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_VoucherStock_Code'
                  AND object_id = OBJECT_ID('dbo.VoucherStock_Table'))
BEGIN
    DROP INDEX UQ_VoucherStock_Code ON dbo.VoucherStock_Table;
    PRINT '  dropped UQ_VoucherStock_Code (index)';
END

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VoucherStock_Provider_Status'
             AND object_id = OBJECT_ID('dbo.VoucherStock_Table'))
BEGIN
    DROP INDEX IX_VoucherStock_Provider_Status ON dbo.VoucherStock_Table;
    PRINT '  dropped IX_VoucherStock_Provider_Status';
END
GO

/* ---------- 4. convert the columns ------------------------------
   Add alongside, encrypt into it, drop the original, rename over the
   top. Guarded on the current type, so re-running this file is a
   no-op rather than a second round of encryption.

   Dynamic SQL because a column added in this batch is not visible to
   statements compiled in the same batch. */
IF NOT EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'VoucherDataKey')
BEGIN
    RAISERROR('VoucherDataKey is not open - nothing was converted. Nothing has been lost either; open the key and re-run.', 16, 1);
    RETURN;
END

DECLARE @Cols TABLE (Seq INT IDENTITY(1,1), Tbl SYSNAME, Col SYSNAME);

INSERT INTO @Cols (Tbl, Col) VALUES
    ('dbo.VoucherStock_Table',   'VoucherCode'),
    ('dbo.VoucherStock_Table',   'CandidateName'),
    ('dbo.VoucherStock_Table',   'Remarks'),
    ('dbo.VoucherStock_Table',   'DealerName'),
    ('dbo.VoucherStock_Table',   'DealerName2'),
    ('dbo.VoucherDealer_Table',  'DealerName'),
    ('dbo.VoucherHistory_Table', 'VoucherCode');

DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @Cols);
DECLARE @t SYSNAME, @c SYSNAME, @sql NVARCHAR(MAX);

WHILE @i <= @n
BEGIN
    SELECT @t = Tbl, @c = Col FROM @Cols WHERE Seq = @i;
    SET @i += 1;

    IF COL_LENGTH(@t, @c) IS NULL
    BEGIN
        PRINT '  skipped (no such column): ' + @t + '.' + @c;
        CONTINUE;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.columns sc
                   JOIN sys.types st ON st.user_type_id = sc.user_type_id
                   WHERE sc.object_id = OBJECT_ID(@t) AND sc.name = @c
                     AND st.name IN ('nvarchar', 'varchar', 'nchar', 'char'))
    BEGIN
        PRINT '  already encrypted: ' + @t + '.' + @c;
        CONTINUE;
    END

    SET @sql = 'ALTER TABLE ' + @t + ' ADD ' + QUOTENAME(@c + '__enc') + ' VARBINARY(MAX) NULL;';
    EXEC sp_executesql @sql;

    SET @sql = 'UPDATE ' + @t +
               '   SET ' + QUOTENAME(@c + '__enc') +
               '     = ENCRYPTBYKEY(KEY_GUID(''VoucherDataKey''), ' + QUOTENAME(@c) + ')' +
               ' WHERE ' + QUOTENAME(@c) + ' IS NOT NULL;';
    EXEC sp_executesql @sql;

    SET @sql = 'ALTER TABLE ' + @t + ' DROP COLUMN ' + QUOTENAME(@c) + ';';
    EXEC sp_executesql @sql;

    SET @sql = 'EXEC sp_rename ''' + @t + '.' + @c + '__enc'', ''' + @c + ''', ''COLUMN'';';
    EXEC sp_executesql @sql;

    PRINT '  encrypted ' + @t + '.' + @c;
END
GO

/* ---------- 5. uniqueness, on the hash instead ------------------- */
IF EXISTS (SELECT 1 FROM dbo.VoucherStock_Table WHERE VoucherCodeHash IS NULL)
    RAISERROR('Some rows have no VoucherCodeHash - the unique index cannot be trusted.', 16, 1);
GO

IF COL_LENGTH('dbo.VoucherStock_Table', 'VoucherCodeHash') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.VoucherStock_Table')
                 AND name = 'VoucherCodeHash' AND is_nullable = 1)
   AND NOT EXISTS (SELECT 1 FROM dbo.VoucherStock_Table WHERE VoucherCodeHash IS NULL)
BEGIN
    ALTER TABLE dbo.VoucherStock_Table ALTER COLUMN VoucherCodeHash VARBINARY(32) NOT NULL;
    PRINT '  VoucherCodeHash set NOT NULL';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_VoucherStock_CodeHash'
                 AND object_id = OBJECT_ID('dbo.VoucherStock_Table'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UQ_VoucherStock_CodeHash
        ON dbo.VoucherStock_Table (VoucherCodeHash);
    PRINT '  created UQ_VoucherStock_CodeHash';
END
GO

/* Same index as before, minus VoucherCode - ciphertext covers nothing. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VoucherStock_Provider_Status'
                 AND object_id = OBJECT_ID('dbo.VoucherStock_Table'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_VoucherStock_Provider_Status
        ON dbo.VoucherStock_Table (ProviderId, Status)
        INCLUDE (ProductId, SaleDate);
    PRINT '  rebuilt IX_VoucherStock_Provider_Status';
END
GO

CLOSE SYMMETRIC KEY VoucherDataKey;
GO

/* ---------- 6. who may use the key ------------------------------
   LocalDB with integrated security runs as dbo and needs nothing. A
   production login does. Replace the name and run:

     GRANT VIEW DEFINITION ON SYMMETRIC KEY::VoucherDataKey TO [dsl_app];
     GRANT VIEW DEFINITION ON CERTIFICATE::VoucherDataCert  TO [dsl_app];

   ---------- 7. checking it worked -------------------------------

     SELECT TOP 5 VoucherCode FROM dbo.VoucherStock_Table;
     -- ciphertext, unreadable

     OPEN SYMMETRIC KEY VoucherDataKey DECRYPTION BY CERTIFICATE VoucherDataCert;
     SELECT TOP 5 CONVERT(NVARCHAR(200), DECRYPTBYKEY(VoucherCode))
     FROM dbo.VoucherStock_Table;
     CLOSE SYMMETRIC KEY VoucherDataKey;
     -- the codes back

   ---------- 8. back up the certificate --------------------------
   Do this now, keep the .cer and .pvk somewhere other than the
   database server, and keep the password with them:

     BACKUP CERTIFICATE VoucherDataCert
         TO FILE = 'C:\SqlBackup\VoucherDataCert.cer'
         WITH PRIVATE KEY (
             FILE = 'C:\SqlBackup\VoucherDataCert.pvk',
             ENCRYPTION BY PASSWORD = '<put a real password here>');

   Restoring onto a different server, before the database is used:

     CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<the master key password>';
     CREATE CERTIFICATE VoucherDataCert
         FROM FILE = 'C:\SqlBackup\VoucherDataCert.cer'
         WITH PRIVATE KEY (
             FILE = 'C:\SqlBackup\VoucherDataCert.pvk',
             DECRYPTION BY PASSWORD = '<the backup password>');
   ============================================================ */

PRINT 'Voucher columns encrypted (VoucherDataKey / VoucherDataCert)';
GO
