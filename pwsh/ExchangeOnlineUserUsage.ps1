# Connect to Exchange Online
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline

# Get mailbox usage for all Exchange Online users
$users = Get-Mailbox -ResultSize unlimited
$mailboxUsage = foreach($User in $users){ get-mailboxstatistics $User.UserPrincipalName | Select-Object DisplayName, @{name='UPN';expression={$user.UserPrincipalName}}, @{name=”TotalItemSize (GB)”;expression={[math]::Round((($_.TotalItemSize.Value.ToString()).Split(“(“)[1].Split(” “)[0].Replace(“,”,””)/1GB),2)}},ItemCount}

# Output mailbox usage as Markdown table
Write-Output "| Display Name | User Principal Name | Total Item Size (GB) | Item Count |"
Write-Output "| --- | --- | --- | --- |"
$mailboxUsage | ForEach-Object {
    $displayName = $_.DisplayName
    $upn = $_.UPN
    $totalItemSize = "{0:N2}" -f $_.'TotalItemSize (GB)'
    $itemCount = $_.ItemCount
    Write-Output "| $displayName | $upn | $totalItemSize | $itemCount |"
}

