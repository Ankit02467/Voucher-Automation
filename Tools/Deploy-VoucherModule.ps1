<#
.SYNOPSIS
    Installs the voucher module into a database that does not have it yet.

.DESCRIPTION
    Database/README.md says to run the migration folders in numeric order. On
    anything but a scratch database that destroys data - see DEPLOYMENT.md
    section 1. This script runs the subset that is safe, in the order that
    works, and skips the rest:

      skipped, deletes or overwrites data
        04_Updates/02_Reseed_VoucherStatus_Demo.sql   empties all three tables
        04_Updates/03_EarlyExpiry_Toggle.sql          rewrites every ExpiryDate
        04_Updates/05_ToBeExpired.sql                 rewrites every ExpiryDate
        99_DevSeed/                                   120 demo vouchers

      skipped, nothing would be lost
        The only schema in 03_EarlyExpiry and 05_ToBeExpired is another copy of
        Sp_VoucherProvider_Table, and 07_Revision3/02 supersedes it.
        06_Revision2/03 and /05 are superseded copies of Sp_VoucherStock_Table.
        06_Revision2/04's product half is superseded by 07_Revision3/01.

      skipped, sample rows that are not the real catalogue
        03_SeedData/01_Seed_Voucher.sql   'Pearson VUE', 'Prometric', ...

      skipped, creates logins - see -WithTestUsers below
        05_ViewData/05_Seed_VoucherUsers.sql
        06_Revision2/04_Students_And_Products.sql

    Every script it does run is re-runnable, so the whole script is.

    Two things it does that the folders do not:

      - It repoints USE DSL_New at -Database, so a database with a different
        name - or a dot in its name - works without editing thirty files.
      - It runs 09_Staging/01_Providers_Seed.sql before 07_Revision3/01, which
        needs the providers to exist to attach products to them.

.PARAMETER MasterKeyPassword
    Encrypts the database master key, alongside the service master key.
    Required, because 08_Encryption ships with a placeholder and sending that
    placeholder to a real server is worse than being made to choose. Record it:
    if the service master key is ever lost, this is the only way back to the
    voucher codes. DEPLOYMENT.md section 2.

.PARAMETER WithTestUsers
    Also creates the four test accounts, every one with the password
    Voucher@123 and one of them a full Voucher Admin. That password is in the
    script comments, in CLAUDE.md and in this repository's git history, so it
    is not a secret from anyone who can reach the site. Off unless asked for,
    and not on a server the internet can see.

.EXAMPLE
    .\Deploy-VoucherModule.ps1 -ListOnly

    .\Deploy-VoucherModule.ps1 -Server 10.0.0.1 -Database DSL_New `
        -User dbadmin -Password *** -MasterKeyPassword '...' -TrustServerCertificate
#>
[CmdletBinding()]
param(
    [string] $Server   = '(localdb)\MSSQLLocalDB',
    [string] $Database = 'DSL_New',
    [string] $User,
    [string] $Password,
    [string] $MasterKeyPassword,
    [switch] $WithTestUsers,
    [switch] $TrustServerCertificate,
    [switch] $ListOnly
)

$ErrorActionPreference = 'Stop'

$root     = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$dbFolder = Join-Path (Split-Path -Parent $root) 'Database'

# Order matters more than the folder numbers do, and it is not the order
# DEPLOYMENT.md section 2 gives. Two departures, both forced:
#
#   09_Staging/01 sits before 07_Revision3/01, because that script attaches
#   products to providers by name and attaches none - without complaining -
#   if the providers are not there yet.
#
#   07_Revision3/03 sits after 07_Revision3/05 and after 08_Encryption. It
#   reads AutoMoveAfter, which 05 adds, and VoucherCodeHash, which
#   08_Encryption adds. SQL Server defers name resolution for a missing
#   *table* but not for a missing *column* on a table that exists, so
#   creating the procedure any earlier fails outright with msg 207. On a
#   database that grew a column at a time this never showed; on a new one it
#   stops the run. Putting it here also means it is created exactly once,
#   already knowing the columns are varbinary - which is what DEPLOYMENT.md
#   was after when it said to run 08 last and then re-run 03.
$scripts = @(
    '01_Tables\01_VoucherProvider_Table.sql'
    '01_Tables\02_VoucherProduct_Table.sql'
    '01_Tables\03_VoucherStock_Table.sql'
    '02_StoredProcedures\01_Sp_VoucherProvider_Table.sql'
    '02_StoredProcedures\02_Sp_VoucherProduct_Table.sql'
    '02_StoredProcedures\03_Sp_VoucherStock_Table.sql'
    '04_Updates\01_VoucherStatus_Screen.sql'
    '04_Updates\04_Rename_Expiry_To_Expired.sql'
    '05_ViewData\01_VoucherStock_Columns.sql'
    '05_ViewData\03_Sp_VoucherStock_ViewData.sql'
    '05_ViewData\04_Fix_BulkInsert_Count.sql'
    '06_Revision2\01_Schema.sql'
    '06_Revision2\02_Sp_VoucherProvider.sql'
    '09_Staging\01_Providers_Seed.sql'
    '07_Revision3\01_Products.sql'
    '09_Staging\02_LanguageCERT_Products.sql'
    '09_Staging\03_Product_Validity.sql'
    '07_Revision3\02_Sp_VoucherProvider.sql'
    '07_Revision3\05_AutoMove_Schema.sql'
    '08_Encryption\01_Encrypt_Voucher_Columns.sql'
    '07_Revision3\03_Sp_VoucherStock.sql'
    '07_Revision3\04_Sp_VoucherPerformance.sql'
)

if ($WithTestUsers) {
    # The four role accounts, then the four students. Not
    # 06_Revision2/04_Students_And_Products.sql, which seeds the same students
    # but then retires every product not called Foundation, Associate or
    # Professional - 13 of the 19 in the real catalogue. 09_Staging/04 is its
    # student half with that second act left out.
    $scripts += '05_ViewData\05_Seed_VoucherUsers.sql'
    $scripts += '09_Staging\04_Student_Users.sql'
}

if ($ListOnly) {
    $i = 0
    foreach ($s in $scripts) { $i++; Write-Output ('{0,2}. {1}' -f $i, $s) }
    exit 0
}

if (-not $MasterKeyPassword) {
    throw "-MasterKeyPassword is required. 08_Encryption ships with the placeholder 'Ch4nge-Me-Before-Production!'; choose a real one and keep it somewhere you will still have after a disaster."
}

# sqlcmd is not on PATH on a bare server.
$sqlcmd = (Get-Command sqlcmd.exe -ErrorAction SilentlyContinue).Source
if (-not $sqlcmd) {
    $sqlcmd = Get-ChildItem 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\*\Tools\Binn\sqlcmd.exe' -ErrorAction SilentlyContinue |
              Sort-Object FullName -Descending |
              Select-Object -First 1 -ExpandProperty FullName
}
if (-not $sqlcmd) { throw 'sqlcmd.exe not found.' }

# -I is not optional. sqlcmd defaults QUOTED_IDENTIFIER off, a procedure keeps
# whatever was in force when it was created, and VoucherStock_Table carries a
# filtered index - so a procedure created without it throws msg 1934 on every
# UPDATE while every SELECT carries on working. The screens load and nothing
# saves. CLAUDE.md trap 7.
$auth = if ($User) { @('-U', $User, '-P', $Password) } else { @('-E') }
if ($TrustServerCertificate) { $auth += '-C' }

$stage = Join-Path $env:TEMP ('voucher-deploy-' + [guid]::NewGuid().ToString('N'))
$null  = New-Item -ItemType Directory -Path $stage

Write-Output ('Deploying the voucher module to [{0}] on {1}' -f $Database, $Server)
Write-Output ''

try {
    $n = 0
    foreach ($rel in $scripts) {
        $n++
        $path = Join-Path $dbFolder $rel
        if (-not (Test-Path $path)) { throw "missing script: $path" }

        $sql = Get-Content -Path $path -Raw

        # The folders all open with USE DSL_New. Brackets, because a database
        # named after a hostname has dots in it.
        $sql = [regex]::Replace($sql, '(?im)^\s*USE\s+\[?DSL_New\]?\s*;?\s*$', ('USE [{0}];' -f $Database))

        # Only ever present in 08_Encryption, and only as the placeholder.
        $sql = $sql.Replace("'Ch4nge-Me-Before-Production!'", ("'{0}'" -f $MasterKeyPassword.Replace("'", "''")))

        $tmp = Join-Path $stage ('{0:d2}_{1}' -f $n, (Split-Path $rel -Leaf))
        Set-Content -Path $tmp -Value $sql -Encoding utf8

        Write-Output ('{0,2}/{1}  {2}' -f $n, $scripts.Count, $rel)

        # -b so a failed batch stops the run, instead of leaving a half-built
        # schema underneath the scripts that follow it.
        & $sqlcmd -S $Server @auth -d $Database -I -b -i $tmp
        if ($LASTEXITCODE -ne 0) {
            throw ('failed on {0} (sqlcmd exit {1})' -f $rel, $LASTEXITCODE)
        }
    }

    Write-Output ''
    Write-Output 'Done.'
    Write-Output 'Back up VoucherDataCert now - DEPLOYMENT.md section 2, and section 8 of the migration.'
    exit 0
}
finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}
