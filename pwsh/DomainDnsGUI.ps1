Add-Type -assembly System.Windows.Forms

#Define the defaultForm
$defaultForm = New-Object System.Windows.Forms.Form
$defaultForm.Text = "DNS Lookup to Markdown"
$defaultForm.Width = 800
$defaultForm.Height = 600
$defaultForm.AutoSize = $true

#Add GUI Components
$DomainLabel = New-Object System.Windows.Forms.Label
$DomainLabel.Text = "Domain Name"
$DomainLabel.Width = 90
$DomainLabel.Location = New-Object System.Drawing.Point(10,15)

$DomainInput = New-Object System.Windows.Forms.TextBox
$DomainInput.Width = 300
$DomainInput.Location = New-Object System.Drawing.Point(100,15)

$DomainLookupBtn = New-Object System.Windows.Forms.Button
$DomainLookupBtn.Text = "Query"
$DomainLookupBtn.Size = New-Object System.Drawing.Size(50,20)
$DomainLookupBtn.Location = New-Object System.Drawing.Point(410,15)

$DomainLookupOut = New-Object System.Windows.Forms.TextBox
$DomainLookupOut.Size = New-Object System.Drawing.Size(780, 470)
$DomainLookupOut.Location = New-Object System.Drawing.Point(10, 50)
$DomainLookupOut.Font = 'Courier,10'
$DomainLookupOut.Multiline = $true;

#Add GUI Components to Default Form
$defaultForm.Controls.AddRange(@($DomainLabel, $DomainInput, $DomainLookupBtn, $DomainLookupOut))

function DomainLookup {

    # Domain Input from Command Line
    $domain = $DomainInput.Text

    # Resolve all records on route of the domain
    $resolve_all = Resolve-DnsName -Name $domain -Type ALL

    # Create the table header
    $table = "### DNS Details for '$($domain)'`r`n`r`n"
    $table += "| Type | Value | Sub Domain |`r`n| ----- | ----- | ----- |`r`n"

    $($resolve_all | ForEach-Object{
        if($($_.Section) -ne 'Additional'){
            $table += "| $($_.QueryType)$($_.Preference) | $($_.NameHost)$($_.IPAddress)$($_.NameExchange)$($_.Strings)$($_.NameAdministrator) | @ |`r`n"
        }
    })

    $autodiscover = Resolve-DnsName -Name "autodiscover.$domain" -Type CNAME
    $table += "| $($autodiscover.QueryType) | $($autodiscover.NameHost) | autodiscover |`r`n"

    $dmarc = Resolve-DnsName -Name "_dmarc.$domain" -Type TXT
    $table += "| $($dmarc.QueryType) | $($dmarc.Strings) | _dmarc |`r`n"

    $dkim1 = Resolve-DnsName -Name "selector1._domainkey.$domain" -Type CNAME
    $table += "| $($dkim1.QueryType) | $($dkim1.NameHost) | selector1._domainkey |`r`n"

    $dkim2 = Resolve-DnsName -Name "selector2._domainkey.$domain" -Type CNAME
    $table += "| $($dkim2.QueryType) | $($dkim2.NameHost) | selector2._domainkey |`r`n"

    # Output results and escape underscores
    $DomainLookupOut.Text = $table.replace('_','\_')

}

$DomainLookupBtn.Add_Click({ DomainLookup })

#Show the default form
$defaultForm.ShowDialog()
