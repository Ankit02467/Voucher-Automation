<#
.SYNOPSIS
    Creates the IIS site and binding for a voucher-module hostname.

.DESCRIPTION
    Run this ON the web server, elevated. It does the part that lives in IIS.
    It cannot do the two parts that live elsewhere, and both have to be in
    place first or the site answers on nothing:

      1. DNS. staging.vcheck.dsucceedlearners.com does not resolve today.
         vcheck.dsucceedlearners.com and staging.dsucceedlearners.com both
         resolve to 150.171.110.85, which is not the SQL Server's address -
         so something (a CDN or front door) sits in front of the web server.
         If it does, the new hostname has to be added there too, not only in
         DNS, or requests never reach IIS at all.

      2. A certificate. The existing certificates are single-name, not
         wildcards:

             CN=staging.dsucceedlearners.com   SAN: that name only
             CN=vcheck.dsucceedlearners.com    SAN: that name only

         So there is nothing already issued that covers the new hostname, and
         a *.dsucceedlearners.com wildcard would not cover it either - it is
         one label deeper. It needs its own certificate, or one for
         *.vcheck.dsucceedlearners.com. Install it into LocalMachine\My and
         pass its thumbprint below.

.PARAMETER Thumbprint
    Certificate for -HostName, already in LocalMachine\My. Omit to create the
    HTTP binding only, which is worth doing first to prove the path end to end
    before involving TLS.

.EXAMPLE
    .\New-VoucherSite.ps1 -PhysicalPath 'C:\inetpub\vcheck-staging' -Thumbprint 'AB12...'
#>
[CmdletBinding()]
param(
    [string] $SiteName     = 'vcheck-staging',
    [string] $HostName     = 'staging.vcheck.dsucceedlearners.com',
    [Parameter(Mandatory = $true)]
    [string] $PhysicalPath,
    [string] $AppPoolName  = 'vcheck-staging',
    [string] $Thumbprint
)

$ErrorActionPreference = 'Stop'
Import-Module WebAdministration

if (-not (Test-Path $PhysicalPath)) {
    New-Item -ItemType Directory -Path $PhysicalPath -Force | Out-Null
    Write-Output "created $PhysicalPath"
}

# .NET CLR v4.0, Integrated - DEPLOYMENT.md section 6.
if (-not (Test-Path "IIS:\AppPools\$AppPoolName")) {
    New-WebAppPool -Name $AppPoolName | Out-Null
    Write-Output "created app pool $AppPoolName"
}
Set-ItemProperty "IIS:\AppPools\$AppPoolName" managedRuntimeVersion 'v4.0'
Set-ItemProperty "IIS:\AppPools\$AppPoolName" managedPipelineMode   'Integrated'

if (-not (Test-Path "IIS:\Sites\$SiteName")) {
    New-Website -Name $SiteName -PhysicalPath $PhysicalPath -ApplicationPool $AppPoolName `
                -HostHeader $HostName -Port 80 | Out-Null
    Write-Output "created site $SiteName  http://$HostName"
} else {
    Write-Output "site $SiteName already exists"
}

if ($Thumbprint) {
    $cert = Get-Item "Cert:\LocalMachine\My\$Thumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) { throw "certificate $Thumbprint is not in LocalMachine\My" }

    # SNI, so this binding can share :443 with the other hostnames on the box.
    if (-not (Get-WebBinding -Name $SiteName -Protocol https -HostHeader $HostName -ErrorAction SilentlyContinue)) {
        New-WebBinding -Name $SiteName -Protocol https -Port 443 -HostHeader $HostName -SslFlags 1
    }
    $b = Get-WebBinding -Name $SiteName -Protocol https -HostHeader $HostName
    $b.AddSslCertificate($Thumbprint, 'My')
    Write-Output "bound https://$HostName to $($cert.Subject)"
} else {
    Write-Output 'no -Thumbprint given: HTTP only, no HTTPS binding created'
}

# The voucher module writes uploads here; the pool identity needs to be able to.
$uploads = Join-Path $PhysicalPath 'Uploads'
if (-not (Test-Path $uploads)) { New-Item -ItemType Directory -Path $uploads -Force | Out-Null }
$acl  = Get-Acl $uploads
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "IIS AppPool\$AppPoolName", 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.SetAccessRule($rule)
Set-Acl $uploads $acl
Write-Output "granted IIS AppPool\$AppPoolName modify on $uploads"

Write-Output ''
Write-Output 'Next: copy the published output into the physical path, then confirm'
Write-Output 'its Web.config carries the staging connection string - an xcopy of a'
Write-Output 'Debug build does not, and every page would fail on the first query.'
