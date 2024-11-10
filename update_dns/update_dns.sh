#!/bin/bash

# Namecheap API credentials from environment variables
API_KEY="$NAMECHEAP_API_KEY"
API_USER="$NAMECHEAP_USER"
CLIENT_IP="$CLIENT_IP"  # Your whitelisted IP address
DOMAIN="$DOMAIN_NAME"
HOST="@"  # @ for root domain or your subdomain

# Get local IPv6 address
IPV6_ADDRESS=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# Parse domain into SLD and TLD
SLD=$(echo "$DOMAIN" | rev | cut -d. -f2 | rev)
TLD=$(echo "$DOMAIN" | rev | cut -d. -f1 | rev)

# Update DNS record using Namecheap API
RESPONSE=$(curl -s "https://api.namecheap.com/xml.response" \
    --get \
    --data-urlencode "ApiUser=$API_USER" \
    --data-urlencode "ApiKey=$API_KEY" \
    --data-urlencode "UserName=$API_USER" \
    --data-urlencode "ClientIp=$CLIENT_IP" \
    --data-urlencode "Command=namecheap.domains.dns.setHosts" \
    --data-urlencode "SLD=$SLD" \
    --data-urlencode "TLD=$TLD" \
    --data-urlencode "HostName1=$HOST" \
    --data-urlencode "RecordType1=AAAA" \
    --data-urlencode "Address1=$IPV6_ADDRESS" \
    --data-urlencode "TTL1=1800")

if echo "$RESPONSE" | grep -q '<ApiResponse Status="OK"'; then
    echo "DNS record updated to $IPV6_ADDRESS"
else
    echo "Failed to update DNS record"
    echo "$RESPONSE"
    exit 1
fi
