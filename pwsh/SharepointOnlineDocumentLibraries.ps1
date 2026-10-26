<#
.SYNOPSIS
Reports document library storage for a SharePoint Online web.
.DESCRIPTION
Uses root-folder storage metrics, not app-catalog storage entities. Uses the current
PnP connection unless SiteUrl is supplied. Hidden libraries are excluded unless
IncludeHidden is set. Metrics may lag changes by several minutes. Writes Markdown
by default, or CSV with numeric bytes/MiB when OutputPath is set. Errors leave
statistics blank rather than reporting zero. Requires PnP.PowerShell.
.EXAMPLE
Connect-PnPOnline -Url https://tenant.sharepoint.com/sites/site -Interactive -ClientId <app-id>
./SharepointOnlineDocumentLibraries.ps1
.EXAMPLE
./SharepointOnlineDocumentLibraries.ps1 -SiteUrl https://tenant.sharepoint.com/sites/site -ClientId <app-id> -OutputPath ./Libraries.csv
#>
[CmdletBinding()]
param (
    [string]$SiteUrl,
    [string]$ClientId,
    [string]$OutputPath,
    [switch]$IncludeHidden
)
Import-Module PnP.PowerShell -ErrorAction Stop
$Connection = $null
try {
    if ($SiteUrl) {
        $Parameters = @{ Url = $SiteUrl; Interactive = $true; ReturnConnection = $true; ErrorAction = 'Stop' }
        if ($ClientId) { $Parameters.ClientId = $ClientId }
        $Connection = Connect-PnPOnline @Parameters
    }
    else {
        $Connection = Get-PnPConnection -ErrorAction Stop
        if ($null -eq $Connection) { throw 'Connect with Connect-PnPOnline first, or supply -SiteUrl.' }
    }
    $Web = Get-PnPWeb -Includes Url -Connection $Connection -ErrorAction Stop
    $Libraries = @(Get-PnPList -Includes RootFolder, Hidden, BaseType -Connection $Connection -ErrorAction Stop |
        Where-Object { [string]$_.BaseType -eq 'DocumentLibrary' -and ($IncludeHidden -or -not $_.Hidden) })
    $ExportedAtUTC = [DateTime]::UtcNow.ToString('o')
    $Results = @(foreach ($Library in $Libraries) {
        $SizeBytes = $null; $SizeMiB = $null; $FileCount = $null; $Failure = ''
        try {
            $Metric = Get-PnPFolderStorageMetric -List $Library.Id -Connection $Connection -ErrorAction Stop
            if ($null -eq $Metric -or $null -eq $Metric.TotalSize) { throw 'No storage size returned.' }
            $SizeBytes = [long]$Metric.TotalSize
            $SizeMiB = [math]::Round($SizeBytes / 1MB, 2)
            $FileCount = $Metric.TotalFileCount
        }
        catch { $Failure = $_.Exception.Message }
        [PSCustomObject]@{
            SiteUrl = $Web.Url; LibraryId = $Library.Id; Name = $Library.Title
            LibraryUrl = $Library.RootFolder.ServerRelativeUrl
            StorageBytes = $SizeBytes; StorageMiB = $SizeMiB; FileCount = $FileCount
            ExportedAtUTC = $ExportedAtUTC; Errors = $Failure
        }
    })
    if ($OutputPath) {
        if ($Results.Count -eq 0) {
            '"SiteUrl","LibraryId","Name","LibraryUrl","StorageBytes","StorageMiB","FileCount","ExportedAtUTC","Errors"' |
                Set-Content -LiteralPath $OutputPath -Encoding UTF8 -ErrorAction Stop
        }
        else { $Results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop }
        Write-Host "Library report saved to: $OutputPath"
    }
    else {
        '| Library | Storage (MiB) | Files | Errors |'
        '| --- | ---: | ---: | --- |'
        foreach ($Result in $Results) {
            $Name = ([string]$Result.Name).Replace('|', '\|') -replace '[\r\n]+', ' '
            $Failure = ([string]$Result.Errors).Replace('|', '\|') -replace '[\r\n]+', ' '
            $Size = if ($null -ne $Result.StorageMiB) { $Result.StorageMiB.ToString('F2', [cultureinfo]::InvariantCulture) } else { '' }
            "| $Name | $Size | $($Result.FileCount) | $Failure |"
        }
    }
    if ($Results.Count -eq 0) { Write-Warning 'No document libraries matched the selected scope.' }
    if (@($Results | Where-Object Errors).Count) { Write-Warning 'Some library metrics failed. Review Errors before using the report.' }
}
finally {
    # Leave the caller's existing PnP session intact.
    $Connection = $null
}
