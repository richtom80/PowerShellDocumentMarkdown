<#
.SYNOPSIS
Exports enterprise-app metadata, assignments, owners and credential-expiry metadata.
.DESCRIPTION
Uses Microsoft.Graph.Authentication. IncludeProvisioning requests the additional
Synchronization.Read.All scope and reads provisioning job metadata. No passwords,
secret values, tokens, private/public certificate data or provisioning credentials
are exported. Does not establish every SAML claim, app connection, external MFA
setting or domain-release dependency. Application owners must validate the result.
.EXAMPLE
./ExportEntraApplicationDependencies.ps1 -TenantId <tenant-id> -OutputFolder ./SVL -IncludeProvisioning
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$TenantId,[string]$OutputFolder='./SVL',[switch]$IncludeProvisioning)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'helpers/TenantDiscovery.Common.ps1')
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
$null=New-Item -ItemType Directory -Path $OutputFolder -Force
$ExportedAtUTC=[DateTime]::UtcNow.ToString('o')
$Issues=[System.Collections.Generic.List[object]]::new();$Coverage=[System.Collections.Generic.List[object]]::new()
$Apps=[System.Collections.Generic.List[object]]::new();$Assignments=[System.Collections.Generic.List[object]]::new();$Owners=[System.Collections.Generic.List[object]]::new();$Credentials=[System.Collections.Generic.List[object]]::new();$Jobs=[System.Collections.Generic.List[object]]::new();$Registrations=[System.Collections.Generic.List[object]]::new()
$Scopes=@('Application.Read.All')
if($IncludeProvisioning){$Scopes+='Synchronization.Read.All'}
$Connected=$false
try{
    Connect-MgGraph -TenantId $TenantId -Scopes $Scopes -ContextScope Process -NoWelcome
    $Connected=$true
    $SPs=Invoke-DiscoveryGraphPaged 'https://graph.microsoft.com/v1.0/servicePrincipals?$select=id,appId,displayName,accountEnabled,servicePrincipalType,preferredSingleSignOnMode,appRoleAssignmentRequired,loginUrl,replyUrls,servicePrincipalNames,keyCredentials,passwordCredentials' 'Enterprise apps' $Issues $Coverage
    foreach($SP in $SPs.Items){
        $Id=$SP.id
        $Apps.Add([pscustomobject]@{ObjectId=$Id;AppId=$SP.appId;DisplayName=$SP.displayName;Enabled=$SP.accountEnabled;Type=$SP.servicePrincipalType;SSOMode=$SP.preferredSingleSignOnMode;AssignmentRequired=$SP.appRoleAssignmentRequired;LoginUrl=$SP.loginUrl;ReplyUrls=$SP.replyUrls -join '; ';Identifiers=$SP.servicePrincipalNames -join '; ';ExportedAtUTC=$ExportedAtUTC})
        $Assigned=Invoke-DiscoveryGraphPaged "https://graph.microsoft.com/v1.0/servicePrincipals/$Id/appRoleAssignedTo" "Assignments: $Id" $Issues $Coverage
        foreach($A in $Assigned.Items){$Assignments.Add([pscustomobject]@{AppObjectId=$Id;AppName=$SP.displayName;PrincipalId=$A.principalId;PrincipalName=$A.principalDisplayName;PrincipalType=$A.principalType;AppRoleId=$A.appRoleId;ExportedAtUTC=$ExportedAtUTC})}
        $AppOwners=Invoke-DiscoveryGraphPaged "https://graph.microsoft.com/v1.0/servicePrincipals/$Id/owners" "Owners: $Id" $Issues $Coverage
        foreach($O in $AppOwners.Items){$Owners.Add([pscustomobject]@{AppObjectId=$Id;AppName=$SP.displayName;OwnerId=$O.id;OwnerType=$O['@odata.type'];ExportedAtUTC=$ExportedAtUTC})}
        foreach($Kind in @('keyCredentials','passwordCredentials')){
            foreach($K in $SP[$Kind]){$Credentials.Add([pscustomobject]@{ObjectType='ServicePrincipal';ObjectId=$Id;AppName=$SP.displayName;CredentialType=$Kind;KeyId=$K.keyId;DisplayName=$K.displayName;StartDateTime=$K.startDateTime;EndDateTime=$K.endDateTime;ExportedAtUTC=$ExportedAtUTC})}
        }
        if($IncludeProvisioning){
            $Provisioning=Invoke-DiscoveryGraphPaged "https://graph.microsoft.com/v1.0/servicePrincipals/$Id/synchronization/jobs" "Provisioning jobs: $Id" $Issues $Coverage
            foreach($J in $Provisioning.Items){$Jobs.Add([pscustomobject]@{AppObjectId=$Id;AppName=$SP.displayName;JobId=$J.id;TemplateId=$J.templateId;ScheduleState=$J.schedule.state;StatusCode=$J.status.code;ExportedAtUTC=$ExportedAtUTC})}
        }
    }
    $ApplicationObjects=Invoke-DiscoveryGraphPaged 'https://graph.microsoft.com/v1.0/applications?$select=id,appId,displayName,signInAudience,keyCredentials,passwordCredentials' 'App registrations' $Issues $Coverage
    foreach($App in $ApplicationObjects.Items){
        $Registrations.Add([pscustomobject]@{ObjectId=$App.id;AppId=$App.appId;DisplayName=$App.displayName;SignInAudience=$App.signInAudience;ExportedAtUTC=$ExportedAtUTC})
        foreach($Kind in @('keyCredentials','passwordCredentials')){
            foreach($K in $App[$Kind]){$Credentials.Add([pscustomobject]@{ObjectType='Application';ObjectId=$App.id;AppName=$App.displayName;CredentialType=$Kind;KeyId=$K.keyId;DisplayName=$K.displayName;StartDateTime=$K.startDateTime;EndDateTime=$K.endDateTime;ExportedAtUTC=$ExportedAtUTC})}
        }
    }
}
catch{
    $Issues.Add([pscustomobject]@{Dataset='Application discovery';Error=$_.Exception.Message;ExportedAtUTC=$ExportedAtUTC})
    $Coverage.Add([pscustomobject]@{Dataset='Application discovery';Status='Partial or failed';Rows=$Apps.Count;ExportedAtUTC=$ExportedAtUTC})
}
finally{
    Write-DiscoveryCsv $Apps (Join-Path $OutputFolder 'EntraApplications.csv') @('ObjectId','AppId','DisplayName','Enabled','Type','SSOMode','AssignmentRequired','LoginUrl','ReplyUrls','Identifiers','ExportedAtUTC')
    Write-DiscoveryCsv $Assignments (Join-Path $OutputFolder 'EntraAppAssignments.csv') @('AppObjectId','AppName','PrincipalId','PrincipalName','PrincipalType','AppRoleId','ExportedAtUTC')
    Write-DiscoveryCsv $Owners (Join-Path $OutputFolder 'EntraAppOwners.csv') @('AppObjectId','AppName','OwnerId','OwnerType','ExportedAtUTC')
    Write-DiscoveryCsv $Credentials (Join-Path $OutputFolder 'EntraCredentialExpiry.csv') @('ObjectType','ObjectId','AppName','CredentialType','KeyId','DisplayName','StartDateTime','EndDateTime','ExportedAtUTC')
    Write-DiscoveryCsv $Registrations (Join-Path $OutputFolder 'EntraAppRegistrations.csv') @('ObjectId','AppId','DisplayName','SignInAudience','ExportedAtUTC')
    Write-DiscoveryCsv $Jobs (Join-Path $OutputFolder 'EntraProvisioningJobs.csv') @('AppObjectId','AppName','JobId','TemplateId','ScheduleState','StatusCode','ExportedAtUTC')
    if(-not $IncludeProvisioning){$Coverage.Add([pscustomobject]@{Dataset='Provisioning jobs';Status='Not requested';Rows=$null;ExportedAtUTC=$ExportedAtUTC})}
    Save-DiscoveryCoverage $Issues $Coverage $OutputFolder 'Entra'
    if($Connected){Disconnect-MgGraph -ErrorAction Continue | Out-Null}
}
