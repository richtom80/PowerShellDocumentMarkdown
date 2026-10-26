<#
.SYNOPSIS
Exports SharePoint role assignments for one or more site collections.
.DESCRIPTION
Reworks the original permissions report with explicit connections, site-list input,
optional item scanning and separate error/coverage CSVs. Reads only. Default scope
is the root web and visible lists/libraries. Recursive visits all descendant webs,
even inherited webs. ScanItemLevel includes folders/files/list items.
Reports assignments, not calculated effective access. Entra group memberships and
sharing-link recipients are not expanded. No access is granted by this script.
.EXAMPLE
./SharepointPermissions.ps1 -SiteUrl https://tenant.sharepoint.com/sites/site -ClientId <app-id> -Recursive -ScanItemLevel
.EXAMPLE
./SharepointPermissions.ps1 -SitesCsv ./SharePointSites.csv -ClientId <app-id> -ReportFile ./Permissions.csv -Recursive -ScanItemLevel
#>
[CmdletBinding(DefaultParameterSetName = 'Urls')]
param (
    [Parameter(Mandatory, ParameterSetName = 'Urls')]
    [ValidateNotNullOrEmpty()]
    [string[]]$SiteUrl,
    [Parameter(Mandatory, ParameterSetName = 'Csv')]
    [string]$SitesCsv,
    [string]$ClientId,
    [string]$ReportFile = (Join-Path (Get-Location) "SitePermissions-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"),
    [switch]$Recursive,
    [switch]$ScanItemLevel,
    [switch]$IncludeInheritedPermissions,
    [switch]$IncludeHiddenLists
)

Import-Module PnP.PowerShell -ErrorAction Stop
if ($PSCmdlet.ParameterSetName -eq 'Csv') {
    $InputRows = @(Import-Csv -LiteralPath $SitesCsv -ErrorAction Stop)
    if ($InputRows.Count -eq 0 -or 'Url' -notin $InputRows[0].PSObject.Properties.Name) {
        throw 'The site CSV must have a Url column and at least one data row.'
    }
    $SiteUrl = @($InputRows | ForEach-Object { $_.Url })
}
$Sites = @($SiteUrl | ForEach-Object { if (-not [string]::IsNullOrWhiteSpace($_)) { $_.Trim().TrimEnd('/') } } | Sort-Object -Unique)
if ($Sites.Count -eq 0) { throw 'No nonblank site URLs were supplied.' }
foreach ($Address in $Sites) {
    $Uri = $null
    if (-not [uri]::TryCreate($Address, [UriKind]::Absolute, [ref]$Uri) -or $Uri.Scheme -ne 'https') {
        throw "Expected an absolute HTTPS site URL: $Address"
    }
}
$Rows = [System.Collections.Generic.List[object]]::new()
$Issues = [System.Collections.Generic.List[object]]::new()
$Coverage = [System.Collections.Generic.List[object]]::new()
$ExportedAtUTC = [DateTime]::UtcNow.ToString('o')
$ReportPath = [IO.Path]::GetFullPath($ReportFile)
$Stem = Join-Path ([IO.Path]::GetDirectoryName($ReportPath)) ([IO.Path]::GetFileNameWithoutExtension($ReportPath))
$ErrorsPath = "$Stem.errors.csv"
$SummaryPath = "$Stem.summary.csv"
if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($ReportPath)) -PathType Container)) {
    throw 'The report parent directory must already exist.'
}

function Add-ScanIssue {
    param($Site, $ObjectUrl, $Stage, $Message)
    $Issues.Add([PSCustomObject]@{ SiteUrl = $Site; ObjectUrl = $ObjectUrl; Stage = $Stage; Error = $Message; ExportedAtUTC = $ExportedAtUTC })
    Write-Warning "$Stage failed for ${ObjectUrl}: $Message"
}
function Open-ReportConnection {
    param($Address)
    $Parameters = @{ Url = $Address; Interactive = $true; ReturnConnection = $true; ErrorAction = 'Stop' }
    if ($ClientId) { $Parameters.ClientId = $ClientId }
    Connect-PnPOnline @Parameters
}
function Get-AbsoluteReportUrl {
    param($WebUrl, $RelativeUrl)
    ([uri]::new([uri]$WebUrl, [string]$RelativeUrl)).AbsoluteUri
}
function Read-RoleAssignments {
    param($Object, $Site, $Web, $ObjectType, $Title, $ObjectUrl, $Connection, [switch]$Always)
    try {
        $null = Get-PnPProperty -ClientObject $Object -Property HasUniqueRoleAssignments -Connection $Connection -ErrorAction Stop
        if (-not $Always -and -not $IncludeInheritedPermissions -and -not $Object.HasUniqueRoleAssignments) { return }
        $null = Get-PnPProperty -ClientObject $Object -Property RoleAssignments -Connection $Connection -ErrorAction Stop
        foreach ($Assignment in $Object.RoleAssignments) {
            try {
                $null = Get-PnPProperty -ClientObject $Assignment -Property RoleDefinitionBindings, Member -Connection $Connection -ErrorAction Stop
                $Roles = @($Assignment.RoleDefinitionBindings | ForEach-Object { $_.Name } | Where-Object { $_ -ne 'Limited Access' })
                if ($Roles.Count -eq 0) { continue }
                $Principal = $Assignment.Member
                $Members = $null; $MemberCount = $null; $MemberStatus = 'Not expanded'
                if ([string]$Principal.PrincipalType -eq 'SharePointGroup') {
                    try {
                        $GroupMembers = @(Get-PnPGroupMember -Group $Principal.Id -Connection $Connection -ErrorAction Stop)
                        $Members = ($GroupMembers | ForEach-Object { $_.LoginName }) -join '; '
                        $MemberCount = $GroupMembers.Count; $MemberStatus = 'Read'
                    }
                    catch { $MemberStatus = 'Failed'; Add-ScanIssue $Site $ObjectUrl 'Group members' $_.Exception.Message }
                }
                $Rows.Add([PSCustomObject]@{
                    SiteUrl = $Site; WebUrl = $Web.Url; ObjectType = $ObjectType; Title = $Title; Url = $ObjectUrl
                    HasUniquePermissions = $Object.HasUniqueRoleAssignments
                    PrincipalId = $Principal.Id; PrincipalName = $Principal.Title; LoginName = $Principal.LoginName
                    PrincipalType = [string]$Principal.PrincipalType; Permissions = $Roles -join '; '
                    SharePointGroupMembers = $Members; GroupMemberCount = $MemberCount; GroupMembersStatus = $MemberStatus
                    ExportedAtUTC = $ExportedAtUTC
                })
            }
            catch { Add-ScanIssue $Site $ObjectUrl 'Role assignment' $_.Exception.Message }
        }
    }
    catch { Add-ScanIssue $Site $ObjectUrl 'Object permissions' $_.Exception.Message }
}

foreach ($Site in $Sites) {
    Write-Host "Scanning $Site"
    $StartErrors = $Issues.Count; $StartRows = $Rows.Count
    $WebsScanned = 0; $ListsScanned = 0; $ItemsScanned = 0; $HiddenSkipped = 0
    $Connection = $null
    try {
        $Connection = Open-ReportConnection $Site
        $RootWeb = Get-PnPWeb -Includes Url, Title -Connection $Connection -ErrorAction Stop
        try {
            foreach ($Admin in @(Get-PnPSiteCollectionAdmin -Connection $Connection -ErrorAction Stop)) {
                $Rows.Add([PSCustomObject]@{
                    SiteUrl = $Site; WebUrl = $RootWeb.Url; ObjectType = 'Site collection'; Title = $RootWeb.Title; Url = $RootWeb.Url
                    HasUniquePermissions = $null; PrincipalId = $Admin.Id; PrincipalName = $Admin.Title; LoginName = $Admin.LoginName
                    PrincipalType = [string]$Admin.PrincipalType; Permissions = 'Site collection administrator'
                    SharePointGroupMembers = $null; GroupMemberCount = $null; GroupMembersStatus = 'Not expanded'; ExportedAtUTC = $ExportedAtUTC
                })
            }
        }
        catch { Add-ScanIssue $Site $Site 'Site administrators' $_.Exception.Message }
        $WebUrls = [System.Collections.Generic.List[string]]::new()
        $WebUrls.Add($RootWeb.Url)
        if ($Recursive) {
            try {
                Get-PnPSubWeb -Recurse -Includes Url -Connection $Connection -ErrorAction Stop |
                    ForEach-Object { $WebUrls.Add($_.Url) }
            }
            catch { Add-ScanIssue $Site $Site 'Subweb enumeration' $_.Exception.Message }
        }
        foreach ($WebUrl in @($WebUrls | Select-Object -Unique)) {
            try {
                if ($WebUrl -ne $RootWeb.Url) { $Connection = Open-ReportConnection $WebUrl }
                $Web = Get-PnPWeb -Includes Url, Title -Connection $Connection -ErrorAction Stop
                $WebsScanned++
                Read-RoleAssignments $Web $Site $Web 'Site' $Web.Title $Web.Url $Connection -Always:($WebUrl -eq $RootWeb.Url)
                $Lists = @(Get-PnPList -Includes Hidden, RootFolder, DefaultDisplayFormUrl -Connection $Connection -ErrorAction Stop)
                foreach ($List in $Lists) {
                    if ($List.Hidden -and -not $IncludeHiddenLists) { $HiddenSkipped++; continue }
                    $ListsScanned++
                    $ListUrl = Get-AbsoluteReportUrl $Web.Url $List.RootFolder.ServerRelativeUrl
                    Read-RoleAssignments $List $Site $Web 'List or library' $List.Title $ListUrl $Connection
                    if ($ScanItemLevel) {
                        try {
                            Get-PnPListItem -List $List.Id -PageSize 500 -Fields Title, FileRef, FileLeafRef -Connection $Connection -ErrorAction Stop |
                                ForEach-Object {
                                    $Item = $_; $ItemsScanned++
                                    try {
                                        $ItemType = if ([string]$Item.FileSystemObjectType -eq 'Folder') { 'Folder' } elseif ($Item.FieldValues['FileLeafRef']) { 'File or item' } else { 'List item' }
                                        $ItemTitle = if ($Item.FieldValues['FileLeafRef']) { $Item.FieldValues['FileLeafRef'] } else { $Item.FieldValues['Title'] }
                                        $Relative = if ($Item.FieldValues['FileRef']) { $Item.FieldValues['FileRef'] } else { "$($List.DefaultDisplayFormUrl)?ID=$($Item.Id)" }
                                        $ItemUrl = Get-AbsoluteReportUrl $Web.Url $Relative
                                        Read-RoleAssignments $Item $Site $Web $ItemType $ItemTitle $ItemUrl $Connection
                                    }
                                    catch { Add-ScanIssue $Site "$ListUrl / item $($Item.Id)" 'Item permissions' $_.Exception.Message }
                                }
                        }
                        catch { Add-ScanIssue $Site $ListUrl 'Item enumeration' $_.Exception.Message }
                    }
                }
            }
            catch { Add-ScanIssue $Site $WebUrl 'Web or list enumeration' $_.Exception.Message }
        }
    }
    catch { Add-ScanIssue $Site $Site 'Site connection or discovery' $_.Exception.Message }
    finally {
        $Connection = $null
        $Coverage.Add([PSCustomObject]@{
            SiteUrl = $Site; Status = if ($Issues.Count -gt $StartErrors) { 'Partial or failed' } else { 'Scanned selected scope' }
            WebsScanned = $WebsScanned; ListsScanned = $ListsScanned; ItemsScanned = $ItemsScanned
            HiddenListsSkipped = $HiddenSkipped; Recursive = [bool]$Recursive; ScanItemLevel = [bool]$ScanItemLevel
            IncludeInheritedPermissions = [bool]$IncludeInheritedPermissions; IncludeHiddenLists = [bool]$IncludeHiddenLists
            AssignmentRows = $Rows.Count - $StartRows; ErrorCount = $Issues.Count - $StartErrors; ExportedAtUTC = $ExportedAtUTC
        })
    }
}
function Write-ReportCsv {
    param($Data, $Path, [string[]]$Columns)
    if ($Data.Count -gt 0) { $Data | Select-Object $Columns | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 -ErrorAction Stop }
    else { ($Columns | ForEach-Object { '"' + $_ + '"' }) -join ',' | Set-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction Stop }
}
Write-ReportCsv $Rows $ReportPath @('SiteUrl','WebUrl','ObjectType','Title','Url','HasUniquePermissions','PrincipalId','PrincipalName','LoginName','PrincipalType','Permissions','SharePointGroupMembers','GroupMemberCount','GroupMembersStatus','ExportedAtUTC')
Write-ReportCsv $Issues $ErrorsPath @('SiteUrl','ObjectUrl','Stage','Error','ExportedAtUTC')
Write-ReportCsv $Coverage $SummaryPath @('SiteUrl','Status','WebsScanned','ListsScanned','ItemsScanned','HiddenListsSkipped','Recursive','ScanItemLevel','IncludeInheritedPermissions','IncludeHiddenLists','AssignmentRows','ErrorCount','ExportedAtUTC')
Write-Host "Permissions: $ReportPath"
Write-Host "Coverage: $SummaryPath"
Write-Host "Errors: $ErrorsPath"
if ($Issues.Count) { Write-Warning "$($Issues.Count) scan error(s). Review the coverage and error reports; results are incomplete." }
