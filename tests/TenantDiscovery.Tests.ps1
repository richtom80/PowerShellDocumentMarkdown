# Offline regression checks; all authentication and remote reads are mocked.
$ErrorActionPreference='Stop'
$Repo=Split-Path $PSScriptRoot -Parent
$Temp=Join-Path ([IO.Path]::GetTempPath()) ('TenantDiscovery-'+[guid]::NewGuid())
$null=New-Item -ItemType Directory $Temp
function Assert-Discovery {param($Condition,$Message) if(-not $Condition){throw $Message}}
function Import-Module {[CmdletBinding()]param($Name)}
function Connect-MgGraph {[CmdletBinding()]param($TenantId,$Scopes,$ContextScope,[switch]$NoWelcome) if($global:DiscoveryTestAuthFailure){throw 'Simulated sign-in failure'}}
function Disconnect-MgGraph {[CmdletBinding()]param()}
function Connect-PnPOnline {[CmdletBinding()]param($Url,$ClientId,[switch]$Interactive,[switch]$ReturnConnection) @{Url=$Url}}
function Get-PnPTenantSite {
    [CmdletBinding()]param([switch]$IncludeOneDriveSites,[switch]$Detailed,$Connection)
    [pscustomobject]@{Owner='user@example.com';Url='https://tenant-my.sharepoint.com/personal/user';Template='SPSPERS#10';StorageUsageCurrent=0;StorageQuota=1024;LockState='Unlock'}
    [pscustomobject]@{Owner='owner';Url='https://tenant.sharepoint.com/sites/team';Template='GROUP#0';StorageUsageCurrent=10}
    if($global:DiscoveryTestOneDriveFailure){throw 'Simulated OneDrive query failure'}
}
function Invoke-MgGraphRequest {
    [CmdletBinding()]param($Method,$Uri,$OutputType)
    if($Uri -match 'mock-page-2'){return @{value=@(@{id='team2';displayName='Second team';visibility='Public'})}}
    if($Uri -match '/groups\?'){return @{value=@(@{id='team1';displayName='First team';visibility='Private'});'@odata.nextLink'='https://graph.microsoft.com/v1.0/mock-page-2'}}
    if($Uri -match '/teams/team2/channels'){throw 'Simulated channels access denied'}
    if($Uri -match '/teams/.*/channels/.*/filesFolder'){return @{webUrl='https://tenant.sharepoint.com/sites/team/Docs'}}
    if($Uri -match '/teams/.*/channels/.*/members'){return @{value=@(@{id='member2';userId='user2';displayName='Private member';email='private@example.com';tenantId='tenant';roles=@()})}}
    if($Uri -match '/teams/.*/channels$'){return @{value=@(@{id='19:private@thread';displayName='Private channel';membershipType='private';webUrl='https://teams.microsoft.com/private'},@{id='19:standard@thread';displayName='General';membershipType='standard'})}}
    if($Uri -match '/teams/.*/members'){return @{value=@(@{id='member1';userId='user1';displayName='Owner';email='owner@example.com';roles=@('owner')})}}
    if($Uri -match '/servicePrincipals\?'){return @{value=@(@{id='sp1';appId='app1';displayName='Test SAML';accountEnabled=$true;servicePrincipalType='Application';preferredSingleSignOnMode='saml';appRoleAssignmentRequired=$true;replyUrls=@('https://app.example.com/saml');servicePrincipalNames=@('app1');keyCredentials=@(@{keyId='key1';endDateTime='2027-01-01';key='DO-NOT-EXPORT-CERT'});passwordCredentials=@(@{keyId='secret1';endDateTime='2027-01-02';secretText='DO-NOT-EXPORT-SECRET'})})}}
    if($Uri -match '/appRoleAssignedTo$'){return @{value=@(@{principalId='group1';principalDisplayName='App users';principalType='Group';appRoleId='role1'})}}
    if($Uri -match '/owners$'){return @{value=@(@{id='owner-id';'@odata.type'='#microsoft.graph.user'})}}
    if($Uri -match '/synchronization/jobs$'){throw 'Simulated provisioning permission denied'}
    if($Uri -match '/applications\?'){return @{value=@(@{id='application1';appId='app1';displayName='Test registration';signInAudience='AzureADMyOrg';passwordCredentials=@(@{keyId='secret2';endDateTime='2027-01-03';secretText='DO-NOT-EXPORT-SECRET'})})}}
    throw "Unexpected mock URI: $Uri"
}
try{
    foreach($Name in @('ExportTeamsInventory.ps1','ExportOneDriveInventory.ps1','ExportEntraApplicationDependencies.ps1','ExportRemainingTenantDiscovery.ps1','helpers/TenantDiscovery.Common.ps1')){
        $Tokens=$null;$Errors=$null
        $null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo "pwsh/$Name"),[ref]$Tokens,[ref]$Errors)
        Assert-Discovery ($Errors.Count -eq 0) "Parse failed: $Name / $Errors"
    }
    & (Join-Path $Repo 'pwsh/ExportTeamsInventory.ps1') -TenantId tenant -OutputFolder $Temp -IncludeFileLocations
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'Teams.csv')).Count -eq 2) 'Paging lost teams'
    $Channels=@(Import-Csv (Join-Path $Temp 'TeamsChannels.csv'))
    Assert-Discovery ($Channels.Count -eq 2) 'Channel count incorrect'
    Assert-Discovery ($Channels[0].FilesUrl -eq 'https://tenant.sharepoint.com/sites/team/Docs') 'Files mapping missing'
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'Teams.errors.csv')).Count -eq 1) 'Channel failure hidden'
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'TeamsMembers.csv') | Where-Object Scope -eq 'Channel direct').Count -eq 1) 'Private channel membership missing'
    $global:DiscoveryTestOneDriveFailure=$false
    & (Join-Path $Repo 'pwsh/ExportOneDriveInventory.ps1') -AdminUrl https://tenant-admin.sharepoint.com -ClientId test -OutputFolder $Temp
    $Drives=@(Import-Csv (Join-Path $Temp 'OneDrive.csv'))
    Assert-Discovery ($Drives.Count -eq 1 -and $Drives[0].StorageUsedMB -eq '0' -and $Drives[0].ItemCount -eq '') 'OneDrive filter / zero / unknown item count failed'
    $global:DiscoveryTestOneDriveFailure=$true
    & (Join-Path $Repo 'pwsh/ExportOneDriveInventory.ps1') -AdminUrl https://tenant-admin.sharepoint.com -OutputFolder $Temp
    Assert-Discovery ((Import-Csv (Join-Path $Temp 'OneDrive.coverage.csv')).Status -eq 'Partial or failed') 'OneDrive partial result hidden'
    & (Join-Path $Repo 'pwsh/ExportEntraApplicationDependencies.ps1') -TenantId tenant -OutputFolder $Temp -IncludeProvisioning
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'EntraApplications.csv')).Count -eq 1) 'Enterprise app missing'
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'EntraCredentialExpiry.csv')).Count -eq 3) 'Expiry metadata missing'
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'Entra.errors.csv')).Count -eq 1) 'Provisioning failure hidden'
    $Content=(Get-ChildItem $Temp -Filter '*.csv' | Get-Content) -join "`n"
    Assert-Discovery ($Content -notmatch 'DO-NOT-EXPORT') 'Credential content leaked'
    # A new no-provisioning run must clear old job/error outputs and state the omitted scope.
    & (Join-Path $Repo 'pwsh/ExportEntraApplicationDependencies.ps1') -TenantId tenant -OutputFolder $Temp
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'Entra.errors.csv')).Count -eq 0) 'Stale errors retained'
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'Entra.coverage.csv') | Where-Object Status -eq 'Not requested').Count -eq 1) 'Omitted scope hidden'
    $global:DiscoveryTestAuthFailure=$true
    & (Join-Path $Repo 'pwsh/ExportTeamsInventory.ps1') -TenantId tenant -OutputFolder $Temp
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'Teams.csv')).Count -eq 0) 'Stale Teams data retained after sign-in failure'
    Assert-Discovery ((Import-Csv (Join-Path $Temp 'Teams.coverage.csv')).Status -eq 'Partial or failed') 'Sign-in failure hidden'
    $global:DiscoveryTestAuthFailure=$false
    $global:DiscoveryTestOneDriveFailure=$false
    & (Join-Path $Repo 'pwsh/ExportRemainingTenantDiscovery.ps1') -TenantId tenant -AdminUrl https://tenant-admin.sharepoint.com -ClientId test -OutputFolder $Temp
    Assert-Discovery (@(Import-Csv (Join-Path $Temp 'RemainingDiscoveryRuns.csv')).Count -eq 3) 'Runner did not record each report'
    Write-Host 'PASS: syntax, paging, access failures, channel membership, OneDrive scope/zero/partial results, app assignments/expiry, secret exclusion and runner.'
}
finally{
    Remove-Item -LiteralPath $Temp -Recurse -Force
    Remove-Variable DiscoveryTestOneDriveFailure,DiscoveryTestAuthFailure -Scope Global -ErrorAction SilentlyContinue
}
