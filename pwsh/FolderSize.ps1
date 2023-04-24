# Script to simulate the du -sh command in PowerShell and output the results to a markdown table
# Path: pwsh\FolderSize.ps1

# Read piped input from command line and store in variable
$dir = $args[0]
if ($dir -eq $null) { $dir = Read-Host "Enter the directory to scan" }

# Declare the array to store the results
$folderSize = @()

# Get a list of all the subdirectories in the directory and store in variable for first level only
$subDirs = Get-ChildItem -Path $dir -Directory

# Loop through each subdirectory
foreach ($subDir in $subDirs)
{
    # Get the size of the subdirectory and store in variable
    $size = Get-ChildItem -Path $subDir.FullName -Recurse | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum

    # Create a new object to store the subdirectory name and size
    $obj = [pscustomobject]@{
        Name = $subDir.Name
        ByteSize = $size
        Size = [math]::Round($size / 1GB, 2)
    }

    # Add the object to the array
    $folderSize += $obj
}

$sysOut = "# Directory information

> Directory: $dir

| Name | Size (GB) |
| - | - |`n"
$folderSize | ForEach-Object {
    $sysOut += "| $($_.Name) | $($_.Size) |`n"
}

Write-Output $SysOut.replace('\','\\')
