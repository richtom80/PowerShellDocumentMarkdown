# PowerShellDocumentMarkdown

A collection of PowerShell Scripts to Document System and output as MarkDown

I wanted to have a way to document server and computers and output as markdown text, these simple scripts are aimed to help in the process of this.

>[!info]
>These scripts collect basic information only, please contribute to improving these where possible

## PowerShell Scripts

> Source folder `/pwsh`

- ADSecurityDocument.ps1 - This script, when run from a Domain Controller or system with Active Directory tools enabled, will document the AD Security Groups and associated user accounts.
- ADComputerInformation.ps1 - Script to document computers that are joined to AD domain and last logons
- ADUserInformation.ps1 - Script to document users that are joined to AD domain and last logons
- DHCPDocument.ps1 - This script, when run from a Domain Controller or system with DHCP tools installed will document the Windows DHCP Server.
- DomainDns.ps1 - This script, when run from any system will use the DNS domain tools to query a domain name and all associated records.  In addition it will also document the _dmarc subdomain TXT record and standard DKIM records for O365 (selector1 & selector2). `.\DomainDns.ps1 example.com` to run
- ServerDocument.ps1 - This script is designed to document a Windows Server recording details including memory, storage, networking, shares, roles and installed software.
- FolderSize.ps1 - Takes a directory and outputs the first level folder size in markdown as Folder Name and Size in GB, similar to "du -l 1"
- ExchangeOnlneUserUsage.ps1 - Documents the users mailbox usage in GBs and Item count
- [ExportExchangeOnlineMailboxSizes.ps1](pwsh/ExportExchangeOnlineMailboxSizes.ps1) - Exports user and shared mailbox sizes, active archive sizes, item counts and lookup errors to CSV.

### Exchange Online mailbox size export

Install the module once if required:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

Run from the repository root and sign in to the source tenant with an account permitted to read mailbox statistics:

```powershell
./pwsh/ExportExchangeOnlineMailboxSizes.ps1

# Optional sign-in hint and output location
./pwsh/ExportExchangeOnlineMailboxSizes.ps1 -UserPrincipalName admin@example.com -OutputPath ./MailboxSizes.csv
```

The default output is a timestamped CSV in the current directory. An explicit output path replaces an existing file at that location; its parent directory must exist.

The export includes primary mailbox and active archive sizes and item counts. Sizes retain Exchange's reported text rather than numeric GB values. Review `Errors` before using the data: failed lookups leave statistics blank, and inactive archives also have blank archive statistics. Empty mailboxes can legitimately have zero items. The script reads statistics only, disconnects when finished and does not change mailboxes or export email contents. It covers user and shared mailboxes, not room/equipment, group, inactive or soft-deleted mailboxes.

Microsoft reference: [Get-EXOMailboxStatistics](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-exomailboxstatistics?view=exchange-ps).

### SharePoint library storage and permissions

Both scripts require a compatible PowerShell version and the `PnP.PowerShell` module. Interactive authentication needs your own Entra application client ID, or the equivalent PnP environment configuration. The signed-in account and app must have permission to read the selected sites. Neither script grants access or changes permissions.

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser

# Library storage for one web, in Markdown
Connect-PnPOnline -Url https://tenant.sharepoint.com/sites/site -Interactive -ClientId <app-id>
./pwsh/SharepointOnlineDocumentLibraries.ps1

# Or connect explicitly and write numeric storage statistics to CSV
./pwsh/SharepointOnlineDocumentLibraries.ps1 -SiteUrl https://tenant.sharepoint.com/sites/site -ClientId <app-id> -OutputPath ./Libraries.csv

# Site/list permissions, including descendant webs
./pwsh/thirdparty/SharepointPermissions.ps1 -SiteUrl https://tenant.sharepoint.com/sites/site -ClientId <app-id> -ReportFile ./Permissions.csv -Recursive

# The client's site CSV can be used directly; it must contain a Url column
./pwsh/thirdparty/SharepointPermissions.ps1 -SitesCsv ./SharePointSites.csv -ClientId <app-id> -ReportFile ./Permissions.csv -Recursive -ScanItemLevel
```

Library storage uses [Get-PnPFolderStorageMetric](https://pnp.github.io/powershell/cmdlets/Get-PnPFolderStorageMetric.html). `StorageBytes` is the reported total storage, `StorageMiB` is bytes divided by 1,048,576, and `FileCount` is the metric's file count. Storage metrics can lag recent changes. Hidden libraries are excluded unless `-IncludeHidden` is supplied. A failed lookup produces blank statistics and an error, rather than a zero. The library report covers the connected web, not all webs or the tenant. Markdown is the default; `-OutputPath` writes CSV.

The permissions script writes three files: assignments (`Permissions.csv`), coverage (`Permissions.summary.csv`) and errors (`Permissions.errors.csv`). Review all three before treating the results as complete. Each run replaces those output files, including writing fresh header-only files when there are no rows; use a new filename to preserve an earlier run. Output directories must already exist.

By default, permissions cover the root web and nonhidden lists/libraries, with inherited assignments omitted below the root web. `-Recursive` visits all descendant webs even where their own permissions are inherited. `-ScanItemLevel` inspects folders/files/list items and can be slow on large sites. `-IncludeInheritedPermissions` includes inherited assignments; `-IncludeHiddenLists` includes hidden lists. Visible libraries such as Site Pages and Site Assets are not excluded by name.

Reports show role assignments and direct SharePoint-group members, including empty groups. They do not expand nested Entra groups, calculate effective access, or enumerate sharing-link recipients. Restricted or inaccessible content is recorded as a scan error; the script does not elevate the caller. For authentication details see [Connect-PnPOnline](https://pnp.github.io/powershell/cmdlets/Connect-PnPOnline.html).

Offline regression checks (mock data only, no tenant connection):

```powershell
pwsh -NoProfile -File ./tests/SharePointReports.Tests.ps1
```

### Teams OneDrive and application discovery

The remaining discovery reports can be collected with PowerShell:

- `pwsh/ExportTeamsInventory.ps1`: Teams, hosted channels, team members and direct private/shared channel members. `-IncludeFileLocations` also attempts to map each channel to its files folder.
- `pwsh/ExportOneDriveInventory.ps1`: existing OneDrive sites, owners, storage, quota and lock state. Item counts are marked not collected, not zero.
- `pwsh/ExportEntraApplicationDependencies.ps1`: enterprise applications, SSO mode, assignments, owner IDs, app registrations and credential expiry metadata. `-IncludeProvisioning` adds provisioning job metadata. No secret values, certificate contents or provisioning credentials are exported.
- `pwsh/ExportRemainingTenantDiscovery.ps1`: runs those three reports with file-location and provisioning lookups enabled, continuing if a report fails.

Install prerequisites once. Then run from the repository root:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module PnP.PowerShell -Scope CurrentUser

$TenantId = Read-Host 'SVL source tenant ID'
$AdminUrl = Read-Host 'SharePoint admin URL, e.g. https://tenant-admin.sharepoint.com'
$ClientId = Read-Host 'Approved PnP application client ID'

./pwsh/ExportRemainingTenantDiscovery.ps1 -TenantId $TenantId -AdminUrl $AdminUrl -ClientId $ClientId -OutputFolder ./SVL
```

Use PowerShell supported by the installed modules. The Graph scripts sign in with process-scoped delegated access. Teams requests `Group.Read.All`, `TeamMember.Read.All`, `Channel.ReadBasic.All`, `ChannelMember.Read.All` and, for file locations, `Files.Read.All`. Applications requests `Application.Read.All` and optionally `Synchronization.Read.All`. These permissions may need administrator consent; provisioning metadata also requires an appropriate Entra role. OneDrive requires SharePoint tenant-administrator access and an approved PnP application. The PnP client ID is not used by the Graph sign-in.

All scripts read metadata only and write CSVs locally. Fixed output filenames are replaced on each run. Review `RemainingDiscoveryRuns.csv` and each report's `.coverage.csv` and `.errors.csv`; zero rows accompanied by an error are not evidence that nothing exists. Existing report files may remain if a report cannot start because a prerequisite is missing. Use a fresh output folder for a new collection when preserving earlier results matters.

Teams visibility depends on the signed-in account and consent; compare results to the supplied team/site inventories. Incoming shared channels hosted by other teams/tenants and indirect shared-channel members are not enumerated. Standard-channel membership follows its team. Message/chat contents, recordings and Planner data are not exported. OneDrive only covers already provisioned sites returned by the admin service; it does not create drives or grant access, and does not measure item counts, links or file permissions. Applications need owner review for full SAML claims, external MFA/Duo configuration and domain-release dependencies. Planner/Forms/flows/Power Apps/Power BI still require their own workload assessment.

References: [Graph channel members](https://learn.microsoft.com/en-us/graph/api/channel-list-members?view=graph-rest-1.0), [PnP tenant sites](https://pnp.github.io/powershell/cmdlets/Get-PnPTenantSite.html), [Graph service principals](https://learn.microsoft.com/en-us/graph/api/serviceprincipal-list?view=graph-rest-1.0), [Graph provisioning jobs](https://learn.microsoft.com/en-us/graph/api/synchronization-synchronization-list-jobs?view=graph-rest-1.0).

Offline checks:

```powershell
pwsh -NoProfile -File ./tests/TenantDiscovery.Tests.ps1
```
