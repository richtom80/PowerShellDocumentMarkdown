# Shared CSV and Microsoft Graph paging helpers. Dot-source from report scripts.
function Write-DiscoveryCsv {
    param($Rows, [string]$Path, [string[]]$Columns)
    if ($Rows.Count -gt 0) { $Rows | Select-Object $Columns | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 -ErrorAction Stop }
    else { ($Columns | ForEach-Object { '"' + $_ + '"' }) -join ',' | Set-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop }
}
function Invoke-DiscoveryGraphPaged {
    param([string]$Uri, [string]$Dataset, $Issues, $Coverage)
    $Items = [System.Collections.Generic.List[object]]::new()
    $Succeeded = $true
    try {
        while ($Uri) {
            $Page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType Hashtable -ErrorAction Stop
            foreach ($Item in $Page['value']) { $Items.Add($Item) }
            $Uri = $Page['@odata.nextLink']
        }
    }
    catch {
        $Succeeded = $false
        $Issues.Add([pscustomobject]@{ Dataset=$Dataset; Error=$_.Exception.Message; ExportedAtUTC=$ExportedAtUTC })
        Write-Warning "$Dataset failed: $($_.Exception.Message)"
    }
    $Coverage.Add([pscustomobject]@{Dataset=$Dataset;Status=if($Succeeded){'Read'}else{'Partial or failed'};Rows=$Items.Count;ExportedAtUTC=$ExportedAtUTC})
    [pscustomobject]@{Succeeded=$Succeeded;Items=$Items}
}
function Save-DiscoveryCoverage {
    param($Issues, $Coverage, $OutputFolder, $Prefix)
    Write-DiscoveryCsv $Issues (Join-Path $OutputFolder "$Prefix.errors.csv") @('Dataset','Error','ExportedAtUTC')
    Write-DiscoveryCsv $Coverage (Join-Path $OutputFolder "$Prefix.coverage.csv") @('Dataset','Status','Rows','ExportedAtUTC')
    if ($Issues.Count) { Write-Warning "$Prefix has $($Issues.Count) failed or partial queries. Review its errors and coverage files." }
}
