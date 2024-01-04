# Get list of domains from text file piped in from command line
# and check if they have DNS records
#
# Usage: cat ./omainListDNS.ps1 domains.txt

# N.B. domains.txt should be a list of domains, one per line


$domains = Get-Content -Path $args[0]

#Create the table header
$table = "### DNS Details for '$($domain)'`r`n`r`n"
$table += "| Domain | MX | SPF | DKIM | DMARC |`r`n| ----- | ----- | ----- | ----- | ----- |`r`n"


#loop through each domain and test for SPF record and MX record
foreach($domain in $domains){
    $spf = Resolve-DnsName -Name "_spf.$domain" -Type TXT
    $mx = Resolve-DnsName -Name $domain -Type MX
    $dkim1 = Resolve-DnsName -Name "selector1._domainkey.$domain" -Type CNAME
    $dkim2 = Resolve-DnsName -Name "selector2._domainkey.$domain" -Type CNAME
    $gsuite_dkim = Resolve-DnsName -Name "google._domainkey.$domain" -Type TXT
    $dmarc = Resolve-DnsName -Name "_dmarc.$domain" -Type TXT

    #foreach $spf record, add it to the table
    foreach($record in $spf){
        if($record.Strings[0].StartsWith('v=spf1')){
            $table += $($record.Strings[0])
        }
    }

    $table += " | Selector1: "+ $($dkim1.Strings) + " Selector2: "+ $($dkim2.Strings) + " google: "+ $($gsuite_dkim.Strings) + " | "+ $($dmarc.Strings) + " |`r`n"
    }
}

#Output the table
Write-Output $table.replace('_','\_')  