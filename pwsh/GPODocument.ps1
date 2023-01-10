# Get all GPOs
$gpos = Get-GPO -All

$output = "## GPO Objects`n"

# Output information in Markdown table format
# Loop through each GPO
foreach ($gp in $gpos) {
    
   
    # Create a new line in the table for the GPO
    $output += "`n### GPO - $($gp.DisplayName)`n`n"

    $output += "- Status: $($gp.GpoStatus)`n"
    $output += "- ID: $($gp.Id)`n"
    $output += "- Created: $($gp.CreationTime)`n`n"

    $output += "| Scope | Name | State |`n"
    $output += "|-------|------|-------|`n"

    [xml]$GpoXml = Get-GPOReport -Guid $($gp.Id) -ReportType Xml

    #Create a custom object containing only the policy "fields" we're interested in
    foreach ($p in $GpoXml.GPO.User.ExtensionData.Extension.Policy) {
         $output += "| User | $($p.Name) | $($p.State) |`n"
    }

    foreach ($p in $GpoXml.GPO.Computer.ExtensionData.Extension.Policy) {
         $output += "| Computer | $($p.Name) | $($p.State) |`n"
    }
   
}

# Print the output
Write-Output $output.replace('_','\_').replace('$','\$')
