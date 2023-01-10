#!/usr/bin/env zsh

fqdn=$1

if [[ -z "$fqdn" ]]; then
  echo "Please provide a fully-qualified domain name (FQDN) as an argument."
  exit 1
fi

# Collect SSL certificate
certificate=$(echo | openssl s_client -showcerts -servername "$fqdn" -connect $fqdn:443 2>/dev/null)

# Extract information from certificate
issuer=$(echo "$certificate" | openssl x509 -noout -issuer)
subject=$(echo "$certificate" | openssl x509 -noout -subject)
start_date=$(echo "$certificate" | openssl x509 -noout -startdate)
expire_date=$(echo "$certificate" | openssl x509 -noout -enddate)
sans=$(echo "$certificate" | openssl x509 -noout -text | grep -A 1 "Subject Alternative Name" | tail -1)

# Output information in Markdown table format
echo "| Field         | Value |"
echo "|---------------|-------|"
echo "| Issuer        | $issuer |"
echo "| Subject       | $subject |"
echo "| Start Date    | $start_date |"
echo "| Expire Date   | $expire_date |"

#loop through each SAN and print them on new line
for san in $(echo $sans | tr ',' '\n'); do
    echo "| SAN | $san |"
done
