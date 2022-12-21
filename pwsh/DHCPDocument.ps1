# Import the DHCP module
Import-Module DhcpServer

# Get the DHCP scope for the DHCP server
$dhcpScope = Get-DHCPServerv4Scope

#Enumerate Scopes

"## DHCP Server"

$($dhcpScope | ForEach-Object {
    "`n### Scope $($_.Name)
    
| Option | Name | Value |
| - | - | - |
| 0 | Scope ID | $($_.ScopeId) |
| 0 | Subnet | $($_.SubnetMask) |
| 0 | Start | $($_.StartRange) |
| 0 | End | $($_.EndRange) |"
    $(Get-DhcpServerv4OptionValue -ScopeId $($_.ScopeId) -All | ForEach-Object {
        "| $($_.OptionId) | $($_.Name) | $($_.Value) |"
    })

    "`n#### Reservations

| MAC | IP | Host | Type |
| - | - | - | - |"
    $(Get-DHCPServerv4Reservation -ScopeId $($_.ScopeId) | ForEach-Object {
        "| $($_.ClientId) | $($_.IpAddress) | $($_.Name) | $($_.Type) |"
    })
})