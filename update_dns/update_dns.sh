#!/bin/bash

# Logging setup
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/update_dns.log
}

# Namecheap API credentials from environment variables
API_KEY="$NAMECHEAP_API_KEY"
API_USER="$NAMECHEAP_USER"
CLIENT_IP="$CLIENT_IP"
DOMAIN="$DOMAIN_NAME"
HOST="@"

# Get current DNS AAAA record
get_dns_record() {
    dig +short AAAA "$DOMAIN" | head -n 1
}

# Get local IPv6 address
get_local_ipv6() {
    ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1
}

# Update DNS record
update_dns() {
    local IPV6_ADDRESS=$1
    
    # Parse domain
    local SLD=$(echo "$DOMAIN" | rev | cut -d. -f2 | rev)
    local TLD=$(echo "$DOMAIN" | rev | cut -d. -f1 | rev)
    
    log "Updating DNS record to $IPV6_ADDRESS"
    
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
        log "DNS record updated successfully"
        return 0
    else
        log "Failed to update DNS record"
        return 1
    fi
}

# Main function to check and update if needed
main() {
    # Get current IPv6
    CURRENT_IPV6=$(get_local_ipv6)
    if [ -z "$CURRENT_IPV6" ]; then
        log "No IPv6 address found"
        return 1
    fi

    # Get current DNS record
    DNS_IPV6=$(get_dns_record)
    
    # Update if different
    if [ "$CURRENT_IPV6" != "$DNS_IPV6" ]; then
        log "IPv6 mismatch - DNS: $DNS_IPV6, Local: $CURRENT_IPV6"
        update_dns "$CURRENT_IPV6"
    else
        log "IPv6 address unchanged, no update needed"
    fi
}

# Run main function
main

# Restart systemd-resolved to apply DNS changes
systemctl restart systemd-resolved
