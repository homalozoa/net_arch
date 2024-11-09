#!/bin/bash

# GoDaddy API credentials from environment variables
API_KEY="$GODADDY_API_KEY"
API_SECRET="$GODADDY_API_SECRET"
DOMAIN="$DOMAIN_NAME"
RECORD_TYPE="AAAA"
RECORD_NAME="@"

# 获取本地IPv6地址
IPV6_ADDRESS=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# 更新DNS记录
curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$RECORD_NAME" \
-H "Authorization: sso-key $API_KEY:$API_SECRET" \
-H "Content-Type: application/json" \
-d "[{\"data\": \"$IPV6_ADDRESS\"}]"

echo "DNS record updated to $IPV6_ADDRESS"
