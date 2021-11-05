#!/bin/bash

# set -x

function help_variables () {
  if [ -z "$PC_REMOTE_IP" ]; then
    echo "Please set environment PC_REMOTE_IP to the remote IP you wish to monitor"
  fi

  if [ -z "$DIGITALOCEAN_TOKEN" ]; then
    echo "Please set environment DIGITALOCEAN_TOKEN to your DigitalOcean Token"
  fi

  if [ -z "$PC_SSH_FINGERPRINT" ]; then
    echo "Please set environment PC_REMOTPC_SSH_FINGERPRINTE_IP fingerprint of the SSH key you wish to use"
  fi
}

if [ -z "$PC_REMOTE_IP" || -z "$DIGITALOCEAN_TOKEN" || -z "$PC_SSH_FINGERPRINT" ]; then
  help_variables();
  exit 1;
fi

DATA='{
  "name":"data-backup",
  "region":"nyc3",
  "size":"s-1vcpu-1gb",
  "image":"docker-20-04",
  "ssh_keys": [
    "'${PC_SSH_FINGERPRINT}'"
  ],
  "backups":false,
  "ipv6":true,
  "user_data":null,
  "private_networking":null,
  "volumes": null,
  "tags": []
}'

ping -c 1 $PC_REMOTE_IP > /dev/null

if [ $? -eq 0 ]; then
  # SERVER IS UP
  echo "UP!"
  RES=`curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        -d "$DATA" \
        https://api.digitalocean.com/v2/droplets`;
  DROPLET_ID=$(echo $RES | jq '.droplet.id')
  echo Droplet ID: $DROPLET_ID
  RES=`curl -s -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        https://api.digitalocean.com/v2/droplets/$DROPLET_ID`
  DROPLET_IP=`echo $RES | jq -r '.droplet.networks.v4[] | select(.type=="public") | .ip_address'`
  echo Droplet IP: $DROPLET_IP

  ssh-keyscan -H 159.203.92.191 2>/dev/null >> ~/.ssh/known_hosts


else
  # SERVER IS DOWN
  echo "DOWN!"
fi