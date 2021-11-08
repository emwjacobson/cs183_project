#!/bin/bash

if [ -z "$CLOUDFLARE_ZONE_ID" ] || [ -z "$CLOUDFLARE_TOKEN" ]; then
  echo "Error, must set CLOUDFLARE_ZONE_ID and CLOUDFLARE_TOKEN!";
  exit 1
fi

curl -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
     -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
     -H "Content-Type:application/json"