#!/bin/bash

V2RAY_CONFIG_PATH="/etc/v2ray/config.json"

SUBSCRIPTION_DATA=$(curl -s "$SUBSCRIPTION_URL" | base64 -d)
IFS=$'\n' read -d '' -r -a LINKS <<< "$SUBSCRIPTION_DATA"

V2RAY_CONFIG='{
  "policy": {
    "system": {
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "log": {
    "access": "",
    "error": "",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "socks",
      "port": 10808,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "routeOnly": false
      },
      "settings": {
        "auth": "noauth",
        "udp": true,
        "allowTransparent": false
      }
    },
    {
      "tag": "http",
      "port": 10809,
      "listen": "0.0.0.0",
      "protocol": "http",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "settings": {
        "auth": "noauth",
        "udp": true,
        "allowTransparent": false
      }
    }
  ],
  "outbounds": []
}'

for LINK in "${LINKS[@]}"; do
  if [[ $LINK == ss://* ]]; then
    # Remove ss:// prefix and decode base64
    SS_CONFIG=$(echo "${LINK#ss://}" | base64 -d)
    
    # Parse the decoded string
    if [[ $SS_CONFIG =~ ([^:]+):([^@]+)@([^:]+):([0-9]+) ]]; then
      METHOD="${BASH_REMATCH[1]}"
      PASSWORD="${BASH_REMATCH[2]}"
      SERVER="${BASH_REMATCH[3]}"
      PORT="${BASH_REMATCH[4]}"

      OUTBOUND=$(jq -n --arg server "$SERVER" --arg port "$PORT" --arg method "$METHOD" --arg password "$PASSWORD" '{
        "protocol": "shadowsocks",
        "settings": {
          "servers": [{
            "address": $server,
            "port": ($port | tonumber),
            "method": $method,
            "password": $password
          }]
        },
        "streamSettings": {
          "network": "tcp"
        }
      }')
      V2RAY_CONFIG=$(echo "$V2RAY_CONFIG" | jq --argjson outbound "$OUTBOUND" '.outbounds += [$outbound]')
    fi
  elif [[ $LINK == vmess://* ]]; then
    VMESS_CONFIG=$(echo "$LINK" | sed 's/vmess:\/\///' | base64 -d)
    ADD=$(echo "$VMESS_CONFIG" | jq -r '.add')
    PORT=$(echo "$VMESS_CONFIG" | jq -r '.port')
    ID=$(echo "$VMESS_CONFIG" | jq -r '.id')
    AID=$(echo "$VMESS_CONFIG" | jq -r '.aid')

    OUTBOUND=$(jq -n --arg add "$ADD" --arg port "$PORT" --arg id "$ID" --arg aid "$AID" '{
      "protocol": "vmess",
      "settings": {
        "vnext": [{
          "address": $add,
          "port": ($port | tonumber),
          "users": [{
            "id": $id,
            "alterId": ($aid | tonumber),
            "security": "auto"
          }]
        }]
      },
      "streamSettings": {
        "network": "tcp"
      }
    }')
    V2RAY_CONFIG=$(echo "$V2RAY_CONFIG" | jq --argjson outbound "$OUTBOUND" '.outbounds += [$outbound]')
  fi
done

echo "$V2RAY_CONFIG" > "$V2RAY_CONFIG_PATH"

systemctl restart v2ray
echo "V2Ray subscription updated and service restarted."
