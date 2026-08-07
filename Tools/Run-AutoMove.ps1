<#
.SYNOPSIS
    Runs the voucher auto-move sweep.

.DESCRIPTION
    A voucher checked by a student belongs to the sub-admin from the next
    midnight. Sp_VoucherStock_Table @Action='AutoMove' moves everything whose
    moment has passed.

    The web application already runs this sweep on every View Data page load, so
    the move has always happened before anyone looks. This script exists so the
    move also lands at midnight itself, without waiting for a visitor.

    The sweep is idempotent: running it twice moves nothing the second time, and
    running it never only delays the move until the next page load. It is safe to
    run this script and keep the page-load sweep - that is the intended setup, the
    script being the punctual path and the page load the safety net.

.PARAMETER Server
    SQL Server instance. Defaults to LocalDB.

.PARAMETER Database
    Defaults to DSL_New.

.PARAMETER ConnectionString
    Full override. Use this in production, where Integrated Security will not be
    how the job authenticates.

.EXAMPLE
    .\Run-AutoMove.ps1
    .\Run-AutoMove.ps1 -Server "SQLPROD01" -Database "DSL_New"
#>
[CmdletBinding()]
param(
    [string] $Server           = '(localdb)\MSSQLLocalDB',
    [string] $Database         = 'DSL_New',
    [string] $ConnectionString,
    [string] $LogPath
)

$ErrorActionPreference = 'Stop'

# Not defaulted in the param block: $PSScriptRoot is not yet populated while
# parameter defaults are being bound, which leaves Join-Path with an empty path.
if (-not $LogPath) {
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $LogPath = Join-Path $root 'automove.log'
}

function Write-Log([string] $Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    Write-Output $line
    try { Add-Content -Path $LogPath -Value $line -Encoding utf8 } catch { }
}

if (-not $ConnectionString) {
    $ConnectionString = "Server=$Server;Database=$Database;Integrated Security=True;"
}

try {
    # LocalDB sits shut down until something connects. Starting it explicitly
    # keeps the first connection from timing out on a cold machine.
    if ($Server -like '(localdb)*') {
        $instance = $Server.Split('\')[-1]
        & sqllocaldb start $instance *> $null
    }

    $cn = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
    $cn.Open()

    $cmd = $cn.CreateCommand()
    $cmd.CommandText = 'dbo.Sp_VoucherStock_Table'
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $cmd.CommandTimeout = 300
    $null = $cmd.Parameters.AddWithValue('@Action', 'AutoMove')

    $moved = $cmd.ExecuteScalar()
    $cn.Close()

    Write-Log ("AutoMove ok - {0} voucher(s) moved to the sub admin." -f $moved)
    exit 0
}
catch {
    Write-Log ("AutoMove FAILED - {0}" -f $_.Exception.Message)
    # Non-zero so Task Scheduler records the failure in its Last Run Result.
    exit 1
}
