# Import the Active Directory module
Import-Module ActiveDirectory

# Get all the security groups in Active Directory
$groups = Get-ADGroup -Filter {GroupCategory -eq 'Security'}

# Initialize an empty array to store the group and member information
$groupInfo = @()

# Loop through each group
foreach ($group in $groups)
{
    # Get the members of the group
    $members = Get-ADGroupMember -Identity $group

    # Create a new object to store the group name and members
    $obj = [pscustomobject]@{
        Group = $group.Name
        Members = ($members | Select-Object -ExpandProperty Name) -join ", "
    }

    # Add the object to the array
    $groupInfo += $obj
}

$SysOut += "
## AD Security Groups

| Group | Members |
| - | - |`n"
# Output the results as a markdown table
$($groupInfo | ForEach-Object {
	$SysOut += "| $($_.Group) | $($_.Members) |`n"
})

Write-Output $SysOut