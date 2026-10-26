<#
.SYNOPSIS
Exports existing OneDrive sites from the SharePoint tenant administration service.
.DESCRIPTION
Requires PnP.PowerShell, an approved interactive client ID (or PnP environment
configuration) and SharePoint admin access. Does not grant site access or create
OneDrives. Only existing sites returned by the service are included. Does not
export files, permissions, sharing links or item counts. Item counts are blank,
not zero, because the site inventory does not supply them.
.EXAMPLE
./ExportOneDriveInventory.ps1 -AdminUrl https://tenant-admin.sharepoint.com -ClientId <app-id> -OutputFolder ./SVL
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AdminUrl,[string]$ClientId,[string]$OutputFolder='./SVL')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'helpers/TenantDiscovery.Common.ps1')
Import-Module PnP.PowerShell -ErrorAction Stop
$null=New-Item -ItemType Directory -Path $OutputFolder -Force
$Issues=[System.Collections.Generic.List[object]]::new();$Coverage=[System.Collections.Generic.List[object]]::new();$Rows=[System.Collections.Generic.List[object]]::new()
$ExportedAtUTC=[DateTime]::UtcNow.ToString('o');$Connection=$null
try{
    $Parameters=@{Url=$AdminUrl;Interactive=$true;ReturnConnection=$true;ErrorAction='Stop'}
    if($ClientId){$Parameters.ClientId=$ClientId}
    $Connection=Connect-PnPOnline @Parameters
    Get-PnPTenantSite -IncludeOneDriveSites -Detailed -Connection $Connection -ErrorAction Stop |
        Where-Object { $_.Template -like 'SPSPERS*' } | ForEach-Object {
            $Rows.Add([pscustomobject]@{Owner=$_.Owner;Url=$_.Url;Template=$_.Template;StorageUsedMB=$_.StorageUsageCurrent;StorageQuotaMB=$_.StorageQuota;LockState=[string]$_.LockState;ItemCount=$null;ItemCountStatus='Not collected';ExportedAtUTC=$ExportedAtUTC})
        }
    $Coverage.Add([pscustomobject]@{Dataset='Existing OneDrive sites';Status='Read';Rows=$Rows.Count;ExportedAtUTC=$ExportedAtUTC})
}
catch{
    $Issues.Add([pscustomobject]@{Dataset='Existing OneDrive sites';Error=$_.Exception.Message;ExportedAtUTC=$ExportedAtUTC})
    $Coverage.Add([pscustomobject]@{Dataset='Existing OneDrive sites';Status='Partial or failed';Rows=$Rows.Count;ExportedAtUTC=$ExportedAtUTC})
}
finally{
    Write-DiscoveryCsv $Rows (Join-Path $OutputFolder 'OneDrive.csv') @('Owner','Url','Template','StorageUsedMB','StorageQuotaMB','LockState','ItemCount','ItemCountStatus','ExportedAtUTC')
    Save-DiscoveryCoverage $Issues $Coverage $OutputFolder 'OneDrive'
    $Connection=$null
}
