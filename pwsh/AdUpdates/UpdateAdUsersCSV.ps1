Import-Csv -Path "C:\temp\adinfo.csv" |
ForEach-Object {
    # properties from the csv
    $acct = $_.SamAccountName     # needed for error message

    # create a blank array of the users that are not found
    $usersNotFound = @()

    Try {

        # output the user information to the console
        Write-Host "Updating user: $acct | Office Phone: $($_.officephone) | Department: $($_.department) | Title: $($_.title)"

        # update the user office phone
        Set-ADUser -Identity $acct -OfficePhone $_.officephone -Department $_.department -Title $_.title -Description $_.description -Company "CompanyXYZ" -Email $_.email -MobilePhone $_.mobile

        # get the manager from the csv remove all white space and convert to lowercase, lookup the manager in AD and set the manager for the user
        $manager = $_.manager.Trim().ToLower()
        # remove all whitespace from manager
        $manager = $manager -replace '\s', ''

        # remove any special characters from the manager
        $manager = $manager -replace '[^a-zA-Z0-9]', ''

        # print the managers name to the console
        Write-Host "Setting manager for $acct to $manager"
        $managerDN = (Get-ADUser -Filter { SamAccountName -eq $manager }).DistinguishedName
        Set-ADUser -Identity $acct -Manager $managerDN 
        
    }
    Catch {
        # add users to the array that are not found
        $usersNotFound += $acct
    }
    
}

# if there are users not found, output them to the console
if ($usersNotFound) {
    Write-Host "The following users were not found: $($usersNotFound -join ', ')"
}