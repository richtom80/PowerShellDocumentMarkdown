# Standalone offline checks. PnP commands are mocked; no modules or tenant required.
$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
$LibraryScript = Join-Path $Repo 'pwsh/SharepointOnlineDocumentLibraries.ps1'
$PermissionScript = Join-Path $Repo 'pwsh/thirdparty/SharepointPermissions.ps1'
$Temp = Join-Path ([IO.Path]::GetTempPath()) ('SharePointReports-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $Temp
function Assert-True { param($Condition, $Message) if (-not $Condition) { throw $Message } }
foreach ($Path in @($LibraryScript, $PermissionScript)) {
    $Tokens = $null; $ParseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$ParseErrors)
    Assert-True ($ParseErrors.Count -eq 0) "Syntax error in ${Path}: $ParseErrors"
}
function Import-Module { [CmdletBinding()] param($Name) }
function Connect-PnPOnline {
    [CmdletBinding()] param($Url, [switch]$Interactive, [switch]$ReturnConnection, $ClientId)
    if ($Url -match '/denied$') { throw 'Simulated access denied' }
    [pscustomobject]@{ Url = $Url }
}
function Get-PnPConnection { [CmdletBinding()] param() [pscustomobject]@{ Url = 'https://tenant.sharepoint.com/sites/test' } }
function New-Assignment {
    param($Id, $Type, $Name, $Role = 'Read')
    [pscustomobject]@{
        Member = [pscustomobject]@{Id=$Id; PrincipalType=$Type; Title=$Name; LoginName=$Name}
        RoleDefinitionBindings = @([pscustomobject]@{Name=$Role})
    }
}
function Get-TestRoles {
    @((New-Assignment 1 'User' 'user@example.com'),
      (New-Assignment 2 'SharePointGroup' 'Empty group'),
      (New-Assignment 3 'SecurityGroup' 'Directory group'),
      (New-Assignment 4 'User' 'Limited user' 'Limited Access'))
    if ($global:SPTestFailedGroup) { New-Assignment 99 'SharePointGroup' 'Unreadable group' }
}
function Get-PnPWeb {
    [CmdletBinding()] param($Includes, $Connection)
    [pscustomobject]@{Url=$Connection.Url; Title='Test web'; HasUniqueRoleAssignments=($Connection.Url -notmatch '/sub$'); RoleAssignments=@(Get-TestRoles)}
}
function Get-PnPList {
    [CmdletBinding()] param($Includes, $Connection)
    if ($global:SPTestLibraryMode) {
        foreach ($Info in @(@('ok','Documents',$false,'DocumentLibrary'),@('zero','Empty',$false,'DocumentLibrary'),@('bad','Unavailable',$false,'DocumentLibrary'),@('hidden','Hidden',$true,'DocumentLibrary'),@('list','Tasks',$false,'GenericList'))) {
            [pscustomobject]@{Id=$Info[0];Title=$Info[1];Hidden=$Info[2];BaseType=$Info[3];RootFolder=[pscustomobject]@{ServerRelativeUrl='/sites/test/'+$Info[0]}}
        }
    }
    else {
        foreach ($Hidden in @($false,$true)) {
            [pscustomobject]@{
                Id=if($Hidden){'hidden'}else{'docs'};Title=if($Hidden){'Hidden'}else{'Site Pages'};Hidden=$Hidden
                RootFolder=[pscustomobject]@{ServerRelativeUrl=([uri]$Connection.Url).AbsolutePath+'/Docs'}
                DefaultDisplayFormUrl=([uri]$Connection.Url).AbsolutePath+'/Docs/Forms/DispForm.aspx'
                HasUniqueRoleAssignments=$false;RoleAssignments=@(Get-TestRoles)
            }
        }
    }
}
function Get-PnPFolderStorageMetric {
    [CmdletBinding()] param($List, $Connection)
    if ($List -eq 'bad') { throw 'Simulated metric failure' }
    [pscustomobject]@{TotalSize=if($List -eq 'zero'){0}else{2097152};TotalFileCount=if($List -eq 'zero'){0}else{2}}
}
function Get-PnPProperty { [CmdletBinding()] param($ClientObject, $Property, $Connection) }
function Get-PnPSiteCollectionAdmin {
    [CmdletBinding()] param($Connection)
    [pscustomobject]@{Id=10;Title='Admin';LoginName='admin@example.com';PrincipalType='User'}
}
function Get-PnPSubWeb {
    [CmdletBinding()] param([switch]$Recurse,$Includes,$Connection)
    @([pscustomobject]@{Url=$Connection.Url+'/sub'},[pscustomobject]@{Url=$Connection.Url+'/sub/deep'})
}
function Get-PnPGroupMember {
    [CmdletBinding()] param($Group,$Connection)
    if ($Group -eq 99) { throw 'Simulated group enumeration failure' }
    # An empty SharePoint group must still have its assignment reported.
}
function Get-PnPListItem {
    [CmdletBinding()] param($List,$PageSize,$Fields,$Connection)
    [pscustomobject]@{Id=1;FileSystemObjectType='Folder';FieldValues=@{FileRef=([uri]$Connection.Url).AbsolutePath+'/Docs/Restricted';FileLeafRef='Restricted'};HasUniqueRoleAssignments=$true;RoleAssignments=@(Get-TestRoles)}
    [pscustomobject]@{Id=2;FileSystemObjectType='File';FieldValues=@{FileRef=([uri]$Connection.Url).AbsolutePath+'/Docs/inherited.txt';FileLeafRef='inherited.txt'};HasUniqueRoleAssignments=$false;RoleAssignments=@(Get-TestRoles)}
}
try {
    $global:SPTestLibraryMode=$true
    $global:SPTestFailedGroup=$false
    $LibPath=Join-Path $Temp 'libraries.csv'
    & $LibraryScript -OutputPath $LibPath
    $Libs=@(Import-Csv $LibPath)
    Assert-True ($Libs.Count -eq 3) 'Library type/hidden filter failed'
    Assert-True (($Libs | Where-Object LibraryId -eq 'ok').StorageBytes -eq '2097152') 'Wrong storage bytes'
    Assert-True (($Libs | Where-Object LibraryId -eq 'ok').StorageMiB -eq '2') 'Wrong MiB conversion'
    Assert-True (($Libs | Where-Object LibraryId -eq 'zero').StorageBytes -eq '0') 'Legitimate zero lost'
    $Bad=$Libs | Where-Object LibraryId -eq 'bad'
    Assert-True ($Bad.StorageBytes -eq '' -and $Bad.Errors -match 'metric failure') 'Failed metric should be blank with error'
    & $LibraryScript -OutputPath $LibPath -IncludeHidden -SiteUrl 'https://tenant.sharepoint.com/sites/test' -ClientId 'test-app'
    Assert-True (@(Import-Csv $LibPath).Count -eq 4) 'IncludeHidden failed'
    $Markdown=@(& $LibraryScript) -join "`n"
    Assert-True ($Markdown -match '\| Empty \| 0.00 \| 0 \|') 'Markdown zero formatting failed'

    $global:SPTestLibraryMode=$false
    $Report=Join-Path $Temp 'permissions.csv'
    & $PermissionScript -SiteUrl 'https://tenant.sharepoint.com/sites/test' -ClientId test-app -ReportFile $Report
    $Summary=@(Import-Csv (Join-Path $Temp 'permissions.summary.csv'))
    Assert-True ($Summary[0].ItemsScanned -eq '0' -and $Summary[0].WebsScanned -eq '1') 'Default scope failed'
    $Perms=@(Import-Csv $Report)
    Assert-True (($Perms | Where-Object PrincipalName -eq 'Empty group').GroupMemberCount -eq '0') 'Empty group assignment lost'
    Assert-True (@($Perms | Where-Object PrincipalName -eq 'Directory group').Count -eq 1) 'Directory principal lost'
    Assert-True (@($Perms | Where-Object PrincipalName -eq 'Limited user').Count -eq 0) 'Limited Access filtering failed'
    Assert-True (@($Perms | Where-Object ObjectType -eq 'List or library').Count -eq 0) 'Inherited list should be omitted by default'

    $Csv=Join-Path $Temp 'sites.csv'
    @('Url','https://tenant.sharepoint.com/sites/test','https://tenant.sharepoint.com/sites/test/','https://tenant.sharepoint.com/sites/denied') | Set-Content $Csv
    $global:SPTestFailedGroup=$true
    & $PermissionScript -SitesCsv $Csv -ClientId test-app -ReportFile $Report -Recursive -ScanItemLevel
    $Summary=@(Import-Csv (Join-Path $Temp 'permissions.summary.csv'))
    $SiteSummary=$Summary | Where-Object SiteUrl -notmatch '/denied$'
    Assert-True ($Summary.Count -eq 2) 'Site deduplication or failure continuation failed'
    Assert-True ($SiteSummary.WebsScanned -eq '3' -and $SiteSummary.ItemsScanned -eq '6') 'Recursive/item scope failed'
    $Perms=@(Import-Csv $Report)
    Assert-True (@($Perms | Where-Object { $_.Url -like '*/sub/Docs/Restricted' }).Count -gt 0) 'Unique item below inherited web/list was missed'
    Assert-True (@($Perms | Where-Object { $_.Url -like '*/sub/deep/Docs/Restricted' }).Count -gt 0) 'Nested unique item missed'
    Assert-True (@($Perms | Where-Object GroupMembersStatus -eq 'Failed').Count -gt 0) 'Group expansion failure not retained'
    Assert-True (@($Perms | Where-Object Url -like '*inherited.txt').Count -eq 0) 'Inherited items unexpectedly included'
    Assert-True ((Import-Csv (Join-Path $Temp 'permissions.errors.csv')).Count -gt 0) 'Missing error report'

    $global:SPTestFailedGroup=$false
    & $PermissionScript -SiteUrl 'https://tenant.sharepoint.com/sites/test' -ReportFile $Report -ScanItemLevel -IncludeInheritedPermissions -IncludeHiddenLists
    $Perms=@(Import-Csv $Report)
    Assert-True (@($Perms | Where-Object Url -like '*inherited.txt').Count -gt 0) 'Inherited switch failed'
    Assert-True ((Import-Csv (Join-Path $Temp 'permissions.summary.csv')).ListsScanned -eq '2') 'Hidden-list switch failed'
    Assert-True (@(Import-Csv (Join-Path $Temp 'permissions.errors.csv')).Count -eq 0) 'Old errors were not cleared'
    Write-Host 'PASS: syntax, library metrics/zeros/errors, hidden scope, role assignments, empty groups, recursive inherited webs, item scanning, CSV deduplication and error coverage.'
}
finally {
    Remove-Item -LiteralPath $Temp -Recurse -Force
    Remove-Variable SPTestLibraryMode,SPTestFailedGroup -Scope Global -ErrorAction SilentlyContinue
}
