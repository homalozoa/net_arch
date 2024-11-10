#!/bin/bash

V2RAY_CONFIG_PATH="/etc/v2ray/config.json"

SUBSCRIPTION_DATA=$(curl -s "$SUBSCRIPTION_URL" | base64 -d)
IFS=$'\n' read -d '' -r -a LINKS <<< "$SUBSCRIPTION_DATA"

V2RAY_CONFIG='{
  "inbounds": [{
    "port": 10809,
    "listen": "127.0.0.1",
    "protocol": "http",
    "settings": {
      "auth": "noauth",
      "udp": false,
      "ip": "127.0.0.1"
    }
  }],
  "outbounds": []
}'

for LINK in "${LINKS[@]}"; do
  if [[ $LINK == ss://* ]]; then
    SS_CONFIG=$(echo "$LINK" | sed 's/ss:\/\///')
    METHOD=$(echo "$SS_CONFIG" | cut -d':' -f1)
    PASSWORD=$(echo "$SS_CONFIG" | cut -d'@' -f1 | cut -d':' -f2)
    SERVER=$(echo "$SS_CONFIG" | cut -d'@' -f2 | cut -d':' -f1)
    PORT=$(echo "$SS_CONFIG" | cut -d'@' -f2 | cut -d':' -f2)

    OUTBOUND=$(jq -n --arg server "$SERVER" --arg port "$PORT" --arg method "$METHOD" --arg password "$PASSWORD" '{
      "protocol": "shadowsocks",
      "settings": {
        "servers": [{
          "address": $server,
          "port": ($port | tonumber),
          "method": $method,
          "password": $password
        }]
      }
    }')
    V2RAY_CONFIG=$(echo "$V2RAY_CONFIG" | jq --argjson outbound "$OUTBOUND" '.outbounds += [$outbound]')
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
            "alterId": ($aid | tonumber)
          }]
        }]
      }
    }')
    V2RAY_CONFIG=$(echo "$V2RAY_CONFIG" | jq --argjson outbound "$OUTBOUND" '.outbounds += [$outbound]')
  fi
done

echo "$V2RAY_CONFIG" > "$V2RAY_CONFIG_PATH"

systemctl restart v2ray
echo "V2Ray subscription updated and service restarted."
