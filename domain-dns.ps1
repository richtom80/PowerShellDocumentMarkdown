# Domain Input from Command Line
$domain = $args[0]

# Resolve all records on route of the domain
$resolve_all = Resolve-DnsName -Name $domain -Type ALL

# Create the table header
$table = "## DNS Details for '$($domain)'

| Type | Value | Sub Domain |`n| --- | --- | --- |`n"

$($resolve_all | ForEach-Object{
 $table += "| $($_.QueryType)$($_.Preference) | $($_.NameHost)$($_.IPAddress)$($_.NameExchange)$($_.Strings)$($_.NameAdministrator) | @ |`n"
})

$autodiscover = Resolve-DnsName -Name "autodiscover.$domain" -Type CNAME
$table += "| $($autodiscover.QueryType) | $($autodiscover.NameHost) | autodiscover |`n"

$dmarc = Resolve-DnsName -Name "_dmarc.$domain" -Type TXT
$table += "| $($dmarc.QueryType) | $($dmarc.Strings) | _dmarc |`n"

$dkim1 = Resolve-DnsName -Name "selector1._domainkey.$domain" -Type CNAME
$table += "| $($dkim1.QueryType) | $($dkim1.NameHost) | selector1._domainkey |`n"

$dkim2 = Resolve-DnsName -Name "selector2._domainkey.$domain" -Type CNAME
$table += "| $($dkim2.QueryType) | $($dkim2.NameHost) | selector2._domainkey |`n"

echo $table
