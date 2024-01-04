# Get all libraries in SharePoint Online
$libraries = Get-PnPList | Where-Object { $_.BaseTemplate -eq "DocumentLibrary" }

# Create an array to store library information
$libraryInfo = @()

# Iterate through each library and retrieve storage usage
foreach ($library in $libraries) {
    $libraryName = $library.Title
    $storageUsage = Get-PnPStorageEntity -List $libraryName | Where-Object { $_.Key -eq "Size" } | Select-Object -ExpandProperty Value

    # Format storage usage in human-readable format
    $storageUsageFormatted = "{0:N2} MB" -f ($storageUsage / 1MB)

    # Create an object with library information
    $libraryObject = [PSCustomObject]@{
        Name = $libraryName
        StorageUsage = $storageUsageFormatted
    }

    # Add the library object to the array
    $libraryInfo += $libraryObject
}

# Output library information as Markdown table
Write-Output "| Library Name | Storage Usage |"
Write-Output "| --- | --- |"
$libraryInfo | ForEach-Object {
    $libraryName = $_.Name
    $storageUsage = $_.StorageUsage
    Write-Output "| $libraryName | $storageUsage |"
}
