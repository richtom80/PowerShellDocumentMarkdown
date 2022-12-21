# PowerShellDocumentMarkdown

A collection of PowerShell Scripts to Document System and output as MarkDown

I wanted to have a way to document server and computers and output as markdown text, these simple scripts are aimed to help in the process of this.

>[!info]
>These scripts collect basic information only, please contribute to improving these where possible

## PowerShell Scripts

> Source folder `/pwsh`

- ADSecurityDocument.ps1 - This script, when run from a Domain Controller or system with Active Directory tools enabled, will document the AD Security Groups and associated user accounts.
- DHCPDocument.ps1 - This script, when run from a Domain Controller or system with DHCP tools installed will document the Windows DHCP Server.
- DomainDns.ps1 - This script, when run from any system will use the DNS domain tools to query a domain name and all associated records.  In addition it will also document the _dmarc subdomain TXT record and standard DKIM records for O365 (selector1 & selector2). `.\DomainDns.ps1 example.com` to run
- ServerDocument.ps1 - This script is designed to document a Windows Server recording details including memory, storage, networking, shares, roles and installed software.