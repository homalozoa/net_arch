#!/bin/bash

V2RAY_CONFIG_PATH="/etc/v2ray/config.json"

SUBSCRIPTION_DATA=$(curl -s "$SUBSCRIPTION_URL" | base64 --decode)

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

decode_base64_url() {
  local encoded_url="$1"
  local padding=$((4 - ${#encoded_url} % 4))
  if [ $padding -ne 4 ]; then
    encoded_url="${encoded_url}$(printf '%0.s=' $(seq 1 $padding))"
  fi
  echo "$encoded_url" | tr '_-' '/+' | base64 --decode
}

for LINK in "${LINKS[@]}"; do
  if [[ $LINK == ss://* ]]; then
    # Remove ss:// prefix and split at #
    BASE64_PART="${LINK#ss://}"
    REMARK_PORT_PART="${BASE64_PART#*#}"
    BASE64_PART="${BASE64_PART%%#*}"
    
    # Decode base64
    SS_CONFIG=$(decode_base64_url "$BASE64_PART")
    
    # Parse the decoded string
    if [[ $SS_CONFIG =~ ^([^:]+):([^@]+)@([^:]+):([0-9]+)$ ]]; then
      METHOD="${BASH_REMATCH[1]}"
      PASSWORD="${BASH_REMATCH[2]}"
      SERVER="${BASH_REMATCH[3]}"
      PORT="${BASH_REMATCH[4]}"
      REMARK="${REMARK_PORT_PART%%:*}"
      REMARK_PORT="${REMARK_PORT##*:}"

      # Ensure REMARK_PORT is a valid number
      if ! [[ $REMARK_PORT =~ ^[0-9]+$ ]]; then
        REMARK_PORT="0"
      fi

      OUTBOUND=$(jq -n --arg server "$SERVER" --arg port "$PORT" --arg method "$METHOD" --arg password "$PASSWORD" --arg tag "$REMARK" --argjson remark_port "$REMARK_PORT" '{
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
        },
        "tag": $tag,
        "port": $remark_port
      }')

      V2RAY_CONFIG=$(echo "$V2RAY_CONFIG" | jq --argjson outbound "$OUTBOUND" '.outbounds += [$outbound]')
    else
      echo "Failed to parse SS_CONFIG: $SS_CONFIG"
    fi
  elif [[ $LINK == vmess://* ]]; then
    # Remove vmess:// prefix and split at #
    BASE64_PART="${LINK#vmess://}"
    REMARK_PORT_PART="${BASE64_PART#*#}"
    BASE64_PART="${BASE64_PART%%#*}"
    
    # Decode base64
    VMESS_CONFIG=$(decode_base64_url "$BASE64_PART")
    ADD=$(echo "$VMESS_CONFIG" | jq -r '.add')
    PORT=$(echo "$VMESS_CONFIG" | jq -r '.port')
    ID=$(echo "$VMESS_CONFIG" | jq -r '.id')
    AID=$(echo "$VMESS_CONFIG" | jq -r '.aid')
    REMARK="${REMARK_PORT_PART%%:*}"
    REMARK_PORT="${REMARK_PORT##*:}"

    # Ensure REMARK_PORT is a valid number
    if ! [[ $REMARK_PORT =~ ^[0-9]+$ ]]; then
      REMARK_PORT="0"
    fi

    OUTBOUND=$(jq -n --arg add "$ADD" --arg port "$PORT" --arg id "$ID" --arg aid "$AID" --arg tag "$REMARK" --argjson remark_port "$REMARK_PORT" '{
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
      },
      "tag": $tag,
      "port": $remark_port
    }')
    V2RAY_CONFIG=$(echo "$V2RAY_CONFIG" | jq --argjson outbound "$OUTBOUND" '.outbounds += [$outbound]')
  fi
done

echo "$V2RAY_CONFIG" > "$V2RAY_CONFIG_PATH"

# Restart the V2Ray service
systemctl restart v2ray

# Check if the service restart was successful and if the config.json file has more than 100 lines
if systemctl is-active --quiet v2ray; then
  LINE_COUNT=$(wc -l < "$V2RAY_CONFIG_PATH")
  if [ "$LINE_COUNT" -gt 100 ]; then
    echo "V2Ray subscription updated and service restarted."
  else
    echo "V2Ray subscription might updated failed."
  fi
else
  echo "Failed to restart V2Ray service."
  exit 1
fi
