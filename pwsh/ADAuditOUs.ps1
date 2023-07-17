# Import the Active Directory module
Import-Module ActiveDirectory

# Retrieve all OUs from Active Directory
$ous = Get-ADOrganizationalUnit -Filter * -Properties CanonicalName

# Generate the Markdown table header
$table = "| OU | Objects | Object Names |`n|---|---|---|`n"

# Loop through each OU
foreach ($ou in $ous) {
    # Get the OU name and replace special Markdown characters if any
    $ouName = $ou.CanonicalName -replace '_', '\_'
    
    # Retrieve the objects within the OU
    $objects = Get-ADObject -Filter * -SearchBase $ou.DistinguishedName -SearchScope OneLevel
    
    # Get the names of the objects
    $objectNames = $objects | Select-Object -ExpandProperty Name
    
    # Combine the object names into a comma-separated string
    $objectNamesString = $objectNames -join ", "
    
    # Add the OU, object count, and object names to the table
    $table += "| $ouName | $($objects.Count) | $objectNamesString |`n"
}

# Output the Markdown table
$table
