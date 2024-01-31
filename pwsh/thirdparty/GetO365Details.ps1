<#
=============================================================================================
Name:           List all Office 365 email address using PowerShell
Version:        1.0
Website:        m365scripts.com

Script Highlights:
~~~~~~~~~~~~~~~~~~

1.The script uses modern authentication to connect to Exchange Online.    
2.The script can be executed with MFA enabled account too.    
3.Exports report results to CSV file.    
4.Allows you to generate email address report for a specific mailbox type, such as user mailbox, shared mailbox, guest users, contacts, etc. 
5.Automatically installs the EXO V2 module (if not installed already) upon your confirmation.   
6.The script is scheduler friendly. I.e., Credential can be passed as a parameter instead of saving inside the script. 

For detailed script execution: https://m365scripts.com/microsoft365/get-all-office-365-email-address-and-alias-using-powershell
============================================================================================
#>
Param
(
    [Parameter(Mandatory = $false)]
    [string]$UserName,
    [string]$Password,
    [switch]$UserMailboxOnly,
    [switch]$SharedMailboxOnly,
    [Switch]$DistributionGroupOnly,
    [Switch]$DynamicDistributionGroupOnly,
    [switch]$GroupMailboxOnly,
    [switch]$GuestOnly,
    [switch]$ContactOnly
)

Function Connect_Exo {
    #Check for EXO v2 module inatallation
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($Module.count -eq 0) { 
        Write-Host Exchange Online PowerShell V2 module is not available  -ForegroundColor yellow  
        $Confirm = Read-Host Are you sure you want to install module? [Y] Yes [N] No 
        if ($Confirm -match "[yY]") { 
            Write-host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
            Import-Module ExchangeOnlineManagement
        } 
        else { 
            Write-Host EXO V2 module is required to connect Exchange Online.Please install module using Install-Module ExchangeOnlineManagement cmdlet. 
            Exit
        }
    } 
    Write-Host `nConnecting to Exchange Online...
    #Storing credential in script for scheduling purpose/ Passing credential as parameter - Authentication using non-MFA account
    if (($UserName -ne "") -and ($Password -ne "")) {
        $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
        $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        Connect-ExchangeOnline -Credential $Credential
    }
    else {
        Connect-ExchangeOnline
    }
}
Connect_Exo
if ($UserMailboxOnly.IsPresent)
{ $RecipientType = "UserMailbox" }
elseif ($SharedMailboxOnly.IsPresent)
{ $RecipientType = "SharedMailbox" }
elseif ($DistributionGroupOnly.IsPresent)
{ $RecipientType = "MailUniversalDistributionGroup" }
elseif ($GroupMailboxOnly.IsPresent)
{ $RecipientType = "GroupMailbox" }
elseif ($DynamicDistributionGroupOnly.IsPresent)
{ $RecipientType = "DynamicDistributionGroup" }
elseif ($GuestOnly.IsPresent)
{ $RecipientType = "GuestMailUser" }
elseif ($ContactOnly.IsPresent)
{ $RecipientType = "MailContact" }
else {
    $RecipientType = 'RoomMailbox', 'LinkedRoomMailbox', 'EquipmentMailbox', 'SchedulingMailbox', 
    'LegacyMailbox', 'LinkedMailbox', 'UserMailbox', 'MailContact', 'DynamicDistributionGroup', 'MailForestContact', 'MailNonUniversalGroup', 'MailUniversalDistributionGroup', 'MailUniversalSecurityGroup', 
    'RoomList', 'MailUser', 'GuestMailUser', 'GroupMailbox', 'DiscoveryMailbox', 'PublicFolder', 'TeamMailbox', 'SharedMailbox', 'RemoteUserMailbox', 'RemoteRoomMailbox', 'RemoteEquipmentMailbox', 
    'RemoteTeamMailbox', 'RemoteSharedMailbox', 'PublicFolderMailbox', 'SharedWithMailUser'
}

$ExportResult = ""   
$ExportResults = @()  
$OutputCSV = ".\Office365EmailAddressesReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
$Count = 0
#Get all Email addresses in Microsoft 365
Get-Recipient -ResultSize Unlimited -RecipientTypeDetails $RecipientType | ForEach-Object {
    $Count++
    $DisplayName = $_.DisplayName
    Write-Progress -Activity "`n     Retrieving email addresses of $DisplayName.."`n" Processed count: $Count"
    $RecipientTypeDetails = $_.RecipientTypeDetails
    $PrimarySMTPAddress = $_.PrimarySMTPAddress
    $Alias = ($_.EmailAddresses | Where-Object { $_ -clike "smtp:*" } | ForEach-Object { $_ -replace "smtp:", "" }) -join ","
    If ($Alias -eq "") {
        $Alias = "-"
    }

    #Export result to CSV file
    $ExportResult = @{'Display Name' = $DisplayName; 'Recipient Type Details' = $RecipientTypeDetails; 'Primary SMTP Address' = $PrimarySMTPAddress; 'Alias' = $Alias }
    $ExportResults = New-Object PSObject -Property $ExportResult  
    $ExportResults | Select-Object 'Display Name', 'Recipient Type Details', 'Primary SMTP Address', 'Alias' | Export-Csv -Path $OutputCSV -Notype -Append
}

#Open output file after execution
If ($Count -eq 0) {
    Write-Host No objects found
}
else {
    Write-Host `nThe output file contains $Count records`n
    if ((Test-Path -Path $OutputCSV) -eq "True") {
        Write-Host " The output file available in:" -NoNewline -ForegroundColor Yellow; Write-Host $OutputCSV 
        Write-Host `n~~ Script prepared by AdminDroid Community ~~`n -ForegroundColor Green
        Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "admindroid.com" -ForegroundColor Yellow -NoNewline; Write-Host " to get access to 1800+ Microsoft 365 reports. ~~" -ForegroundColor Green `n`n
        $Prompt = New-Object -ComObject wscript.shell   
        $UserInput = $Prompt.popup("Do you want to open output file?",`   
            0, "Open Output File", 4)   
        If ($UserInput -eq 6) {   
            Invoke-Item "$OutputCSV"   
        } 
    }
}

#Disconnect Exchange Online session
Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue