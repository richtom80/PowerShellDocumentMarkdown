<#
.SYNOPSIS
Runs Teams, OneDrive and Entra application discovery into one output folder.
.DESCRIPTION
Requires preinstalled Microsoft.Graph.Authentication and PnP.PowerShell, approved
Graph consent/roles and a PnP client ID. Each report is read-only. Individual report
coverage/errors must be reviewed even when the runner completes. Existing filenames
are replaced. Does not run the separate Exchange or SharePoint permissions scripts.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$TenantId,[Parameter(Mandatory)][string]$AdminUrl,[Parameter(Mandatory)][string]$ClientId,[string]$OutputFolder='./SVL')
$ErrorActionPreference='Stop'
$null=New-Item -ItemType Directory -Path $OutputFolder -Force
$Runs=[System.Collections.Generic.List[object]]::new()
foreach($Task in @(
    @{Name='Teams';Script='ExportTeamsInventory.ps1';Args=@{TenantId=$TenantId;OutputFolder=$OutputFolder;IncludeFileLocations=$true}},
    @{Name='OneDrive';Script='ExportOneDriveInventory.ps1';Args=@{AdminUrl=$AdminUrl;ClientId=$ClientId;OutputFolder=$OutputFolder}},
    @{Name='Entra';Script='ExportEntraApplicationDependencies.ps1';Args=@{TenantId=$TenantId;OutputFolder=$OutputFolder;IncludeProvisioning=$true}}
)){
    try{$Arguments=$Task.Args;& (Join-Path $PSScriptRoot $Task.Script) @Arguments;$Runs.Add([pscustomobject]@{Report=$Task.Name;Status='Finished; review coverage/errors';Error=''})}
    catch{$Runs.Add([pscustomobject]@{Report=$Task.Name;Status='Failed';Error=$_.Exception.Message});Write-Warning "$($Task.Name): $($_.Exception.Message)"}
}
$Runs | Export-Csv -LiteralPath (Join-Path $OutputFolder 'RemainingDiscoveryRuns.csv') -NoTypeInformation -Encoding UTF8
Write-Host "Reports saved to $OutputFolder. Review run, coverage and error CSVs."
