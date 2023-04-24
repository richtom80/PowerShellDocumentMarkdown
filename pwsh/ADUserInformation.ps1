# Script to audit users in Active Directory that have not logged on in the last 30 days
# Path: pwsh\ADUserInformation.ps1

# Import the Active Directory PowerShell module
Import-Module ActiveDirectory

# Get the list of users from the domain
$users = Get-ADUser -Filter * -Properties * | Select-Object Name,LastLogonDate,Enabled,Description,EmailAddress,Office,Department,Title,Company,Manager

# Sort the list by user last logon date
$users = $users | Sort-Object LastLogonDate -Descending

# Create the table header
$table = "## AD User Information
| User Name | Last Logon Date | Enabled | Description | Email Address | Office | Department | Title | Company | Manager |`n| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | `n"

# Loop through each user and add the information to the table
$users | ForEach-Object {
    $table += "| $($_.Name) | $($_.LastLogonDate) | $($_.Enabled) | $($_.Description) | $($_.EmailAddress) | $($_.Office) | $($_.Department) | $($_.Title) | $($_.Company) | $($_.Manager) |`n"
}

# provide a summary of the number of users, how many users have logged on in the last 30 days, and how many users have not logged on in the last 30 days
$last30 = $users | Where-Object { $_.LastLogonDate -gt (Get-Date).AddDays(-30) }
$last30Count = $last30.Count
$notLast30 = $users | Where-Object { $_.LastLogonDate -lt (Get-Date).AddDays(-30) }
$notLast30Count = $notLast30.Count
$userCount = $users.Count

# Add the summary to the table
$table += "`n### Summary

| Description | Total |
| --- | --- |
| Users | $userCount |
| Users Logged On in Last 30 Days | $last30Count |
| Users Not Logged On in Last 30 Days | $notLast30Count |`n"

# Output results and escape underscores
Write-Output $table.replace('_','\_')  
