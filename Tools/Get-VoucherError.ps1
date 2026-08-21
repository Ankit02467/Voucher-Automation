<#
.SYNOPSIS
    Says why the voucher module is throwing on a deployed server.

.DESCRIPTION
    Run this ON the web server, elevated. The site answers remote requests with
    the generic "Runtime Error" page - that is customErrors mode="RemoteOnly"
    doing its job, and it is the right setting for a public site, so the way to
    see the exception is to ask the server rather than to turn the guard off.

    It reports, in order:

      1. The last unhandled ASP.NET exceptions out of the Application event log,
         with their stack traces. This is the real answer nine times out of ten
         and needs no configuration change at all.

      2. The connection string the deployed Web.config actually carries. A
         hand-copied bin\ folder keeps the development one; only a proper
         Release publish carries the transform. The password is masked.

      3. Whether the database is reachable from THIS machine, which is the only
         machine whose opinion matters - a laptop can be firewalled out while
         the web server is not, and the other way round.

      4. The traps that fail on a deployed server while every screen looked fine
         in development. Each one is documented in CLAUDE.md:

         - VoucherDataKey / VoucherDataCert missing, or this login not allowed
           to open the key. Sp_VoucherStock_Table refuses to run without it, so
           voucher-status.aspx works - it never touches the key - and
           voucher-data.aspx throws on its first query. Trap 8.

         - A procedure created with QUOTED_IDENTIFIER off. Every SELECT keeps
           working and every UPDATE throws msg 1934, so pages load and nothing
           saves - and voucher-data.aspx calls AutoMove, an UPDATE, as the very
           first thing in Page_Load. Trap 7.

         - An empty stock table. SUM(CASE ...) over no rows is NULL where
           COUNT(*) is 0, which is what crashed the dashboard cards.

    Everything it runs against the database is read-only. It opens the symmetric
    key to prove the login can, and that lasts only for its own session.

.PARAMETER SiteName
    IIS site to read the physical path from. Ignored if -PhysicalPath is given.

.PARAMETER PhysicalPath
    The deployed folder, for when the site is not in IIS on this machine or is
    an application underneath another site.

.PARAMETER ConnectionString
    Overrides whatever Web.config carries. Use it to test a connection string
    before deploying it.

.PARAMETER Hours
    How far back to read the event log. Default 24.

.EXAMPLE
    .\Get-VoucherError.ps1 -SiteName vcheck
    .\Get-VoucherError.ps1 -PhysicalPath C:\inetpub\vcheck -Hours 2
#>
[CmdletBinding()]
param(
    [string] $SiteName = 'vcheck',
    [string] $PhysicalPath,
    [string] $ConnectionString,
    [int]    $Hours = 24
)

$ErrorActionPreference = 'Continue'

function Write-Head($text) {
    Write-Output ''
    Write-Output ('=' * 72)
    Write-Output ('  ' + $text)
    Write-Output ('=' * 72)
}

# ---------------------------------------------------------------- 1. the error

Write-Head '1. Unhandled ASP.NET exceptions from the Application log'

$since  = (Get-Date).AddHours(-$Hours)
$events = @()

try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName      = 'Application'
        ProviderName = 'ASP.NET 4.0.30319'
        StartTime    = $since
    } -MaxEvents 5 -ErrorAction Stop
} catch {
    # Get-WinEvent throws rather than returning nothing when its filter matches
    # no events, and older boxes log under a plain source name.
    try {
        $events = Get-EventLog -LogName Application -After $since -Newest 200 -ErrorAction Stop |
                  Where-Object { $_.Source -like 'ASP.NET*' -and $_.EntryType -eq 'Error' } |
                  Select-Object -First 5
    } catch { }
}

if (-not $events -or $events.Count -eq 0) {
    Write-Output ('No ASP.NET errors logged in the last ' + $Hours + ' hour(s).')
    Write-Output ''
    Write-Output 'That usually means one of three things:'
    Write-Output '  - the failure is in IIS before ASP.NET runs - a 500.19 from a bad'
    Write-Output '    Web.config, or .NET 4.8 missing. Check the IIS log under'
    Write-Output '    C:\inetpub\logs\LogFiles for the substatus code.'
    Write-Output '  - health monitoring is switched off in Web.config.'
    Write-Output '  - nobody has hit the page since the log was last cleared.'
    Write-Output ''
    Write-Output 'Reproduce it from the server itself and you get the whole page:'
    Write-Output '  start http://localhost/voucher-data.aspx?providerId=1'
    Write-Output 'RemoteOnly shows a local request everything, so this leaks nothing.'
} else {
    foreach ($e in $events) {
        $when = $e.TimeCreated
        if (-not $when) { $when = $e.TimeGenerated }
        $msg = $e.Message
        if (-not $msg) { $msg = ($e.ReplacementStrings -join "`n") }

        Write-Output ''
        Write-Output ('--- ' + $when + ' ---')
        Write-Output $msg
    }
}

# ------------------------------------------------------- 2. the deployed config

Write-Head '2. Deployed Web.config'

if (-not $PhysicalPath) {
    try {
        Import-Module WebAdministration -ErrorAction Stop
        $site = Get-Item ('IIS:\Sites\' + $SiteName) -ErrorAction Stop
        # IIS stores %SystemDrive%-style paths verbatim.
        $PhysicalPath = [Environment]::ExpandEnvironmentVariables($site.physicalPath)
    } catch {
        Write-Output ("Could not read IIS site '" + $SiteName + "' - pass -PhysicalPath instead.")
    }
}

$cs = $ConnectionString

if ($PhysicalPath) {
    Write-Output ('physical path : ' + $PhysicalPath)
    $cfg = Join-Path $PhysicalPath 'Web.config'

    if (Test-Path $cfg) {
        [xml] $xml = Get-Content $cfg -Raw
        $node = $xml.configuration.connectionStrings.add | Where-Object { $_.name -eq 'con' }

        if (-not $node) {
            Write-Output 'PROBLEM: no connection string named "con".'
            Write-Output '         SqlHelper.cs reads ConnectionStrings["con"] and nothing else,'
            Write-Output '         so every page fails on its first query. CLAUDE.md trap 4.'
        } else {
            $shown = [regex]::Replace($node.connectionString, '(?i)(password|pwd)\s*=\s*[^;]*', '$1=***')
            Write-Output ('connection    : ' + $shown)
            if (-not $cs) { $cs = $node.connectionString }

            if ($node.connectionString -match '(?i)localdb') {
                Write-Output ''
                Write-Output 'PROBLEM: this is still the LocalDB development string. The Release'
                Write-Output '         transform only runs on Publish, never on Build - copying'
                Write-Output '         bin\ and the .aspx files across by hand transforms nothing.'
            }
        }

        $ce = $xml.configuration.'system.web'.customErrors
        if ($ce) { Write-Output ('customErrors  : ' + $ce.mode) }

        $comp = $xml.configuration.'system.web'.compilation
        if ($comp) { Write-Output ('debug         : ' + $comp.debug) }

        $unmapped = $xml.configuration.appSettings.add | Where-Object { $_.key -eq 'VoucherUnmappedIsAdmin' }
        if ($unmapped -and $unmapped.value -eq 'true') {
            Write-Output ''
            Write-Output 'WARNING: VoucherUnmappedIsAdmin is still true. Every account that can'
            Write-Output '         sign in gets the voucher module as an admin. The Release'
            Write-Output '         transform is meant to remove this key.'
        }
    } else {
        Write-Output ('PROBLEM: no Web.config at ' + $cfg)
    }

    $dll = Join-Path $PhysicalPath 'bin\DSL_CMS.dll'
    if (Test-Path $dll) {
        $f = Get-Item $dll
        Write-Output ('build         : DSL_CMS.dll {0:yyyy-MM-dd HH:mm}  ({1:N0} bytes)' -f $f.LastWriteTime, $f.Length)
    } else {
        Write-Output 'PROBLEM: bin\DSL_CMS.dll is not there. The site will not compile.'
    }

    if (-not (Test-Path (Join-Path $PhysicalPath 'Uploads'))) {
        Write-Output 'NOTE: no Uploads folder. Upload Entry will fail when someone uses it.'
    }
}

# --------------------------------------------------------------- 3. the database

Write-Head '3. Database, from this machine'

if (-not $cs) {
    Write-Output 'No connection string to test. Pass -ConnectionString or -PhysicalPath.'
    return
}

# Whatever the config says, this run should fail fast rather than hang a console.
$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $cs
$builder['Connect Timeout'] = 15
$conn = New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString

try {
    $conn.Open()
    Write-Output ('connected to [' + $conn.Database + '] on ' + $conn.DataSource)
} catch {
    Write-Output 'PROBLEM: could not connect.'
    Write-Output ('  ' + $_.Exception.Message)
    Write-Output ''
    Write-Output 'Check the SQL port is open from HERE, not from your laptop:'
    Write-Output ('  Test-NetConnection ' + $builder['Data Source'] + ' -Port 1433')
    Write-Output 'A firewall or IP allowlist that lets one machine in does not let'
    Write-Output 'the other in - they leave from different addresses.'
    return
}

function Invoke-Scalar($sql) {
    $c = $conn.CreateCommand()
    $c.CommandText    = $sql
    $c.CommandTimeout = 30
    try { return $c.ExecuteScalar() } catch { return ('ERROR: ' + $_.Exception.Message) }
}

Write-Output ('server        : ' + (Invoke-Scalar "SELECT CONVERT(varchar,SERVERPROPERTY('ProductVersion'))") +
              '  ' + (Invoke-Scalar "SELECT CONVERT(varchar,SERVERPROPERTY('Edition'))"))
Write-Output ('login         : ' + (Invoke-Scalar 'SELECT SUSER_SNAME()') +
              '  (db_owner=' + (Invoke-Scalar "SELECT IS_ROLEMEMBER('db_owner')") + ')')

# --------------------------------------------------------------- 4. the traps

Write-Head '4. The traps that only bite once deployed'

$missing = Invoke-Scalar @"
SELECT STUFF((SELECT ', ' + n FROM (VALUES
  ('VoucherStock_Table'),('VoucherProvider_Table'),('VoucherProduct_Table'),
  ('VoucherDealer_Table'),('VoucherHistory_Table'),
  ('Sp_VoucherStock_Table'),('Sp_VoucherProvider_Table'),
  ('Sp_VoucherProduct_Table'),('Sp_VoucherPerformance_Table')) v(n)
  WHERE OBJECT_ID('dbo.' + n) IS NULL FOR XML PATH('')), 1, 2, '')
"@

if ($missing -and $missing -isnot [DBNull]) {
    Write-Output ('PROBLEM: these objects do not exist: ' + $missing)
    Write-Output '         The migration folders have not all been run against this database.'
} else {
    Write-Output 'objects       : all present'
}

# --- trap 8, the encryption key
$sym  = Invoke-Scalar "SELECT COUNT(*) FROM sys.symmetric_keys WHERE name = 'VoucherDataKey'"
$cert = Invoke-Scalar "SELECT COUNT(*) FROM sys.certificates  WHERE name = 'VoucherDataCert'"
Write-Output ('key / cert    : VoucherDataKey=' + $sym + '  VoucherDataCert=' + $cert)

if ("$sym" -eq '0' -or "$cert" -eq '0') {
    Write-Output 'PROBLEM: 08_Encryption/01 has not been run here. Sp_VoucherStock_Table'
    Write-Output '         raises instead of running, so voucher-data.aspx throws on load'
    Write-Output '         while voucher-status.aspx - which never touches the key - is fine.'
} else {
    $open = Invoke-Scalar @"
BEGIN TRY
    OPEN SYMMETRIC KEY VoucherDataKey DECRYPTION BY CERTIFICATE VoucherDataCert;
    IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'VoucherDataKey')
        SELECT 'opened';
    ELSE
        SELECT 'refused without raising';
    CLOSE SYMMETRIC KEY VoucherDataKey;
END TRY
BEGIN CATCH
    SELECT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
"@
    Write-Output ('open key      : ' + $open)

    if ("$open" -ne 'opened') {
        Write-Output 'PROBLEM: this login cannot open the key, so Sp_VoucherStock_Table refuses'
        Write-Output '         to run at all. It needs VIEW DEFINITION on the key and on the'
        Write-Output '         certificate - section 6 of'
        Write-Output '         08_Encryption/01_Encrypt_Voucher_Columns.sql. db_owner has it'
        Write-Output '         implicitly; a db_datareader/db_datawriter login does not.'
    }
}

# --- trap 7, QUOTED_IDENTIFIER
$bad = Invoke-Scalar @"
SELECT STUFF((SELECT ', ' + o.name FROM sys.sql_modules m
              JOIN sys.objects o ON o.object_id = m.object_id
              WHERE o.name LIKE 'Sp_Voucher%' AND m.uses_quoted_identifier = 0
              FOR XML PATH('')), 1, 2, '')
"@

if ($bad -and $bad -isnot [DBNull]) {
    Write-Output ('PROBLEM: QUOTED_IDENTIFIER is off on: ' + $bad)
    Write-Output '         VoucherStock_Table carries a filtered index on AutoMoveAfter, so'
    Write-Output '         every UPDATE branch throws msg 1934 while the SELECTs carry on.'
    Write-Output '         voucher-data.aspx calls AutoMove first thing in Page_Load, and'
    Write-Output '         AutoMove is an UPDATE - which is why that page throws and the'
    Write-Output '         others do not. Re-run 07_Revision3 with sqlcmd -I.'
} else {
    Write-Output 'quoted ident  : on for every Sp_Voucher* procedure'
}

$counts = Invoke-Scalar @"
SELECT CONVERT(varchar,(SELECT COUNT(*) FROM dbo.VoucherStock_Table))    + ' stock, '
     + CONVERT(varchar,(SELECT COUNT(*) FROM dbo.VoucherProvider_Table)) + ' providers, '
     + CONVERT(varchar,(SELECT COUNT(*) FROM dbo.VoucherProduct_Table))  + ' products'
"@
Write-Output ('rows          : ' + $counts)

# ------------------------------------------------- 5. the query the page runs

Write-Head '5. The query voucher-data.aspx actually runs'

$c = $conn.CreateCommand()
$c.CommandText    = 'dbo.Sp_VoucherStock_Table'
$c.CommandType    = [System.Data.CommandType]::StoredProcedure
$c.CommandTimeout = 60
$null = $c.Parameters.AddWithValue('@Action', 'Select')
$null = $c.Parameters.AddWithValue('@ProviderId', '1')

try {
    $t = New-Object System.Data.DataTable
    $t.Load($c.ExecuteReader())
    Write-Output ('Select returned {0} row(s), {1} column(s) - the grid query is fine.' -f $t.Rows.Count, $t.Columns.Count)

    if ($t.Rows.Count -gt 0) {
        $code = $t.Rows[0]['VoucherCode']
        if ($code -is [DBNull] -or "$code" -eq '') {
            Write-Output 'PROBLEM: VoucherCode came back empty on a row that exists.'
            Write-Output '         DECRYPTBYKEY returns NULL rather than raising when the key is'
            Write-Output '         shut, so this is the key again, not missing data.'
        }
    }
} catch {
    Write-Output 'PROBLEM: the grid query itself fails. This is very likely the page error:'
    Write-Output ('  ' + $_.Exception.Message)
}

$conn.Close()

Write-Output ''
Write-Output 'Done.'
