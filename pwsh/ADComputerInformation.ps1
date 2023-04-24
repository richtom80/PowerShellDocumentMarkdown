# PowerShell Script to get information about AD joined computers, when they were last seen, and if they are still joined to the domain
# Path: pwsh\ADComputerInformation.ps1

#Import the Active Directory PowerShell module
Import-Module ActiveDirectory

# Get the list of computers from the domain
$computers = Get-ADComputer -Filter * -Properties * | Select-Object Name,LastLogonDate,Enabled,OperatingSystem,OperatingSystemServicePack,OperatingSystemVersion,OperatingSystemSKU,OperatingSystemArchitecture,OperatingSystemLanguage,OperatingSystemHotFix,Description,Location

# Sort the list by computer last logon date
$computers = $computers | Sort-Object LastLogonDate -Descending

# Create the table header
$table = "## AD Computer Information
| Computer Name | Last Logon Date | Operating System | Service Pack | Version | Description | Location |`n| --- | --- | --- | --- | --- | --- | --- | `n"

# Loop through each computer and add the information to the table
$computers | ForEach-Object {
    $table += "| $($_.Name) | $($_.LastLogonDate) | $($_.OperatingSystem) | $($_.OperatingSystemServicePack) | $($_.OperatingSystemVersion) | $($_.Description) | $($_.Location) |`n"
}

# provide a summary of the number of computers, how many computers have logged on in the last 30 days, and how many computers have not logged on in the last 30 days
$last30 = $computers | Where-Object { $_.LastLogonDate -gt (Get-Date).AddDays(-30) }
$last30Count = $last30.Count
$notLast30 = $computers | Where-Object { $_.LastLogonDate -lt (Get-Date).AddDays(-30) }
$notLast30Count = $notLast30.Count
$computerCount = $computers.Count

# Add the summary to the table
$table += "`n### Summary

| Description | Total |
| --- | --- |
| Computers | $computerCount |
| Computers Logged On in Last 30 Days | $last30Count |
| Computers Not Logged On in Last 30 Days | $notLast30Count |`n"

# Output results and escape underscores
Write-Output $table.replace('_','\_')
