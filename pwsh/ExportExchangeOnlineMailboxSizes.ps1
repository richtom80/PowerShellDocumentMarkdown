<#
.SYNOPSIS
Exports Exchange Online user and shared mailbox sizes and archive statistics to CSV.

.DESCRIPTION
Reads mailbox statistics without changing mailboxes or exporting message content.
Records failed lookups in the Errors column and leaves unavailable statistics blank.
Requires ExchangeOnlineManagement and an account allowed to read mailbox statistics.
Size columns preserve Exchange's reported size text; they are not numeric GB columns.

.PARAMETER OutputPath
CSV destination. Defaults to a timestamped file in the current directory.

.PARAMETER UserPrincipalName
Optional administrator sign-in hint. Sign in to the tenant being assessed.

.EXAMPLE
.\ExportExchangeOnlineMailboxSizes.ps1

.EXAMPLE
.\ExportExchangeOnlineMailboxSizes.ps1 -UserPrincipalName admin@example.com -OutputPath .\MailboxSizes.csv
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path (Get-Location) "MailboxSizes-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"),

    [Parameter()]
    [string]$UserPrincipalName
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

$ConnectionParameters = @{ ErrorAction = 'Stop' }
if (-not [string]::IsNullOrWhiteSpace($UserPrincipalName)) {
    $ConnectionParameters.UserPrincipalName = $UserPrincipalName
}

Connect-ExchangeOnline @ConnectionParameters
try {
    $ExportedAtUTC = [DateTime]::UtcNow.ToString('o')
    $Mailboxes = @(Get-EXOMailbox -ResultSize Unlimited `
        -RecipientTypeDetails UserMailbox, SharedMailbox `
        -Properties ArchiveStatus -ErrorAction Stop)

    $Results = foreach ($Mailbox in $Mailboxes) {
        $Email = [string]$Mailbox.PrimarySmtpAddress
        $Primary = $null
        $Archive = $null
        $Errors = @()

        Write-Verbose "Reading $Email"
        if ([string]::IsNullOrWhiteSpace($Email)) {
            $Errors += 'Missing primary SMTP address; statistics were not queried.'
        }
        else {
            try {
                $Primary = Get-EXOMailboxStatistics `
                    -PrimarySmtpAddress $Email -ErrorAction Stop
            }
            catch {
                $Errors += "Mailbox: $($_.Exception.Message)"
            }

            if ($Mailbox.ArchiveStatus -eq 'Active') {
                try {
                    $Archive = Get-EXOMailboxStatistics `
                        -PrimarySmtpAddress $Email -Archive -ErrorAction Stop
                }
                catch {
                    $Errors += "Archive: $($_.Exception.Message)"
                }
            }
        }

        [PSCustomObject]@{
            DisplayName      = $Mailbox.DisplayName
            EmailAddress     = $Email
            RecipientType    = $Mailbox.RecipientTypeDetails
            MailboxSize      = if ($Primary) { [string]$Primary.TotalItemSize } else { $null }
            MailboxItemCount = if ($Primary) { $Primary.ItemCount } else { $null }
            ArchiveStatus    = $Mailbox.ArchiveStatus
            ArchiveSize      = if ($Archive) { [string]$Archive.TotalItemSize } else { $null }
            ArchiveItemCount = if ($Archive) { $Archive.ItemCount } else { $null }
            ExportedAtUTC    = $ExportedAtUTC
            Errors           = $Errors -join ' | '
        }
    }

    if ($Mailboxes.Count -eq 0) {
        Write-Warning 'No user or shared mailboxes returned. No CSV was written.'
    }
    else {
        $Results | Sort-Object EmailAddress |
            Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Host "Export saved to: $OutputPath"
        Write-Host 'Review the Errors column before using the results.'
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue
}
