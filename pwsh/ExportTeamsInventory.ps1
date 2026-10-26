<#
.SYNOPSIS
Exports Teams, hosted channels and membership metadata through Microsoft Graph.
.DESCRIPTION
Requires Microsoft.Graph.Authentication and approved delegated read scopes.
Does not export messages, chats, recordings or Planner content. Visibility depends
on the account and Graph permissions; a successful call is not proof of full
tenant coverage. Channel membership is direct membership only, not indirect shared
channel membership. Incoming shared channels hosted elsewhere are not inventoried.
IncludeFileLocations requests Files.Read.All and attempts a filesFolder lookup.
.EXAMPLE
./ExportTeamsInventory.ps1 -TenantId <tenant-id> -OutputFolder ./SVL -IncludeFileLocations
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$TenantId, [string]$OutputFolder='./SVL', [switch]$IncludeFileLocations)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'helpers/TenantDiscovery.Common.ps1')
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
$null=New-Item -ItemType Directory -Path $OutputFolder -Force
$Issues=[System.Collections.Generic.List[object]]::new();$Coverage=[System.Collections.Generic.List[object]]::new()
$Teams=[System.Collections.Generic.List[object]]::new();$Channels=[System.Collections.Generic.List[object]]::new();$Members=[System.Collections.Generic.List[object]]::new()
$ExportedAtUTC=[DateTime]::UtcNow.ToString('o')
$Scopes=@('Group.Read.All','TeamMember.Read.All','Channel.ReadBasic.All','ChannelMember.Read.All')
if($IncludeFileLocations){$Scopes+='Files.Read.All'}
$Connected=$false
try {
    Connect-MgGraph -TenantId $TenantId -Scopes $Scopes -ContextScope Process -NoWelcome
    $Connected=$true
    $Result=Invoke-DiscoveryGraphPaged 'https://graph.microsoft.com/v1.0/groups?$filter=resourceProvisioningOptions/Any(x:x%20eq%20%27Team%27)&$select=id,displayName,visibility' 'Teams groups' $Issues $Coverage
    foreach($Team in $Result.Items){
        $Id=$Team.id
        $Teams.Add([pscustomobject]@{TeamId=$Id;TeamName=$Team.displayName;Visibility=$Team.visibility;ExportedAtUTC=$ExportedAtUTC})
        $TeamMembers=Invoke-DiscoveryGraphPaged "https://graph.microsoft.com/v1.0/teams/$Id/members" "Team members: $Id" $Issues $Coverage
        foreach($Member in $TeamMembers.Items){$Members.Add([pscustomobject]@{TeamId=$Id;ChannelId=$null;Scope='Team';MemberId=$Member.id;UserId=$Member.userId;DisplayName=$Member.displayName;Email=$Member.email;TenantId=$Member.tenantId;Roles=$Member.roles -join '; ';ExportedAtUTC=$ExportedAtUTC})}
        $TeamChannels=Invoke-DiscoveryGraphPaged "https://graph.microsoft.com/v1.0/teams/$Id/channels" "Hosted channels: $Id" $Issues $Coverage
        foreach($Channel in $TeamChannels.Items){
            $ChannelId=[uri]::EscapeDataString($Channel.id);$FilesUrl=$null;$FilesStatus='Not requested'
            if($IncludeFileLocations){
                try{$Folder=Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/teams/$Id/channels/$ChannelId/filesFolder" -OutputType Hashtable -ErrorAction Stop;$FilesUrl=$Folder.webUrl;$FilesStatus='Read'}
                catch{$FilesStatus='Failed';$Issues.Add([pscustomobject]@{Dataset="Files folder: $Id / $($Channel.id)";Error=$_.Exception.Message;ExportedAtUTC=$ExportedAtUTC})}
            }
            $Channels.Add([pscustomobject]@{TeamId=$Id;TeamName=$Team.displayName;ChannelId=$Channel.id;ChannelName=$Channel.displayName;MembershipType=$Channel.membershipType;WebUrl=$Channel.webUrl;FilesUrl=$FilesUrl;FilesLookupStatus=$FilesStatus;ExportedAtUTC=$ExportedAtUTC})
            # Standard-channel membership follows the team; export explicit private/shared membership.
            if($Channel.membershipType -ne 'standard'){
                $ChannelMembers=Invoke-DiscoveryGraphPaged "https://graph.microsoft.com/v1.0/teams/$Id/channels/$ChannelId/members" "Channel members: $Id / $($Channel.id)" $Issues $Coverage
                foreach($Member in $ChannelMembers.Items){$Members.Add([pscustomobject]@{TeamId=$Id;ChannelId=$Channel.id;Scope='Channel direct';MemberId=$Member.id;UserId=$Member.userId;DisplayName=$Member.displayName;Email=$Member.email;TenantId=$Member.tenantId;Roles=$Member.roles -join '; ';ExportedAtUTC=$ExportedAtUTC})}
            }
        }
    }
}
catch{
    $Issues.Add([pscustomobject]@{Dataset='Teams discovery';Error=$_.Exception.Message;ExportedAtUTC=$ExportedAtUTC})
    $Coverage.Add([pscustomobject]@{Dataset='Teams discovery';Status='Partial or failed';Rows=$Teams.Count;ExportedAtUTC=$ExportedAtUTC})
}
finally{
    Write-DiscoveryCsv $Teams (Join-Path $OutputFolder 'Teams.csv') @('TeamId','TeamName','Visibility','ExportedAtUTC')
    Write-DiscoveryCsv $Channels (Join-Path $OutputFolder 'TeamsChannels.csv') @('TeamId','TeamName','ChannelId','ChannelName','MembershipType','WebUrl','FilesUrl','FilesLookupStatus','ExportedAtUTC')
    Write-DiscoveryCsv $Members (Join-Path $OutputFolder 'TeamsMembers.csv') @('TeamId','ChannelId','Scope','MemberId','UserId','DisplayName','Email','TenantId','Roles','ExportedAtUTC')
    Save-DiscoveryCoverage $Issues $Coverage $OutputFolder 'Teams'
    if($Connected){Disconnect-MgGraph -ErrorAction Continue | Out-Null}
}
