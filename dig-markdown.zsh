#!/bin/zsh

# Store the output of the dig command in a variable
output=$(dig $1 ANY)

# Output the markdown header
echo "## DNS Details for '$1'
"

# Initialize variables to store the table data
table_data=()

# Flag to indicate whether we are currently in the ANSWER SECTION
in_answer_section=false

# Loop through each line of the output
while read -r line; do
  # If the line starts with ";; ANSWER SECTION:", set the flag to true
  if [[ $line =~ ^";; ANSWER SECTION:" ]]; then
    in_answer_section=true
  # If the line starts with ";;", set the flag to false
  elif [[ $line =~ ^";;" ]]; then
    in_answer_section=false
  # If we are in the ANSWER SECTION and the line is not empty, add it to the table data
  elif [[ $in_answer_section == true && ! -z "$line" ]]; then
    table_data+=("$line")
  fi
done <<< "$output"

# Output the markdown table header
echo "| Type | Value | Sub Domain |"
echo "|------|-------|------|"

# Loop through the table data and output each line as a table row
for data in "${table_data[@]}"; do
  # Split the data into columns
  columns=($(echo "$data" | awk '{print $1, $2, $3, $4, $5, $6, $7}'))
  if [[ ${columns[4]} == "A" || ${columns[4]} == "TXT" || ${columns[4]} == "MX" ]]; then
    # Output the columns as a table row
    echo "| ${columns[4]} | ${columns[5]} ${columns[6]} ${columns[7]} | @ |"
  fi
done


## Check for DKIM Selector1
dkim1=$(dig selector1._domainkey.$1 CNAME)
# Initialize variables to store the table data
table_data_dkim1=()

# Flag to indicate whether we are currently in the ANSWER SECTION
in_answer_section=false

# Loop through each line of the output
while read -r line; do
  # If the line starts with ";; ANSWER SECTION:", set the flag to true
  if [[ $line =~ ^";; ANSWER SECTION:" ]]; then
    in_answer_section=true
  # If the line starts with ";;", set the flag to false
  elif [[ $line =~ ^";;" ]]; then
    in_answer_section=false
  # If we are in the ANSWER SECTION and the line is not empty, add it to the table data
  elif [[ $in_answer_section == true && ! -z "$line" ]]; then
    table_data_dkim1+=("$line")
  fi
done <<< "$dkim1"

# Loop through the table data and output each line as a table row
for data in "${table_data_dkim1[@]}"; do
  # Split the data into columns
  columns=($(echo "$data" | awk '{print $1, $2, $3, $4, $5, $6, $7}'))
  # Output the columns as a table row
   echo "| DKIM (CNAME) |  ${columns[5]:gs/_/\\_} | selector1.\\_domainkey |"
done

## Check for DKIM Selector2
dkim2=$(dig selector2._domainkey.$1 CNAME)
# Initialize variables to store the table data
table_data_dkim2=()

# Flag to indicate whether we are currently in the ANSWER SECTION
in_answer_section=false

# Loop through each line of the output
while read -r line; do
  # If the line starts with ";; ANSWER SECTION:", set the flag to true
  if [[ $line =~ ^";; ANSWER SECTION:" ]]; then
    in_answer_section=true
  # If the line starts with ";;", set the flag to false
  elif [[ $line =~ ^";;" ]]; then
    in_answer_section=false
  # If we are in the ANSWER SECTION and the line is not empty, add it to the table data
  elif [[ $in_answer_section == true && ! -z "$line" ]]; then
    table_data_dkim2+=("$line")
  fi
done <<< "$dkim2"

# Loop through the table data and output each line as a table row
for data in "${table_data_dkim2[@]}"; do
  # Split the data into columns
  columns=($(echo "$data" | awk '{print $1, $2, $3, $4, $5, $6, $7}'))
  # Output the columns as a table row
  echo "| DKIM (CNAME) | ${columns[5]:gs/_/\\_} | selector2.\\_domainkey |"
done

## Check for DMARC
dmarc=$(dig _dmarc.$1 TXT)
# Initialize variables to store the table data
table_data_dmarc=()

# Flag to indicate whether we are currently in the ANSWER SECTION
in_answer_section=false

# Loop through each line of the output
while read -r line; do
  # If the line starts with ";; ANSWER SECTION:", set the flag to true
  if [[ $line =~ ^";; ANSWER SECTION:" ]]; then
    in_answer_section=true
  # If the line starts with ";;", set the flag to false
  elif [[ $line =~ ^";;" ]]; then
    in_answer_section=false
  # If we are in the ANSWER SECTION and the line is not empty, add it to the table data
  elif [[ $in_answer_section == true && ! -z "$line" ]]; then
    table_data_dmarc+=("$line")
  fi
done <<< "$dmarc"

# Loop through the table data and output each line as a table row
for data in "${table_data_dmarc[@]}"; do
  # Split the data into columns
  columns=($(echo "$data" | awk '{print $1, $2, $3, $4, $5, $6, $7}'))
  # Output the columns as a table row
  echo "| DMARC | ${columns[5]} ${columns[6]} ${columns[7]} | \\_dmarc |"
done