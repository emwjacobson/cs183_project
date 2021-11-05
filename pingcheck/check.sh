#!/bin/bash

# set -x

CONTAINER_NAME=yeasy/simple-web:latest

function help_variables {
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

if [ -z "$PC_REMOTE_IP" ] || [ -z "$DIGITALOCEAN_TOKEN" ] || [ -z "$PC_SSH_FINGERPRINT" ]; then
  help_variables
  exit 1
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

# Check if server is up by pinging it
ping -c 1 $PC_REMOTE_IP > /dev/null

if [ $? -eq 0 ]; then
  # SERVER IS UP
  echo "UP!"

  # Rent the machine and get its droplet ID
  RES=`curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        -d "$DATA" \
        https://api.digitalocean.com/v2/droplets`;
  DROPLET_ID=$(echo $RES | jq '.droplet.id')
  echo Droplet ID: $DROPLET_ID

  sleep 20 # Need to make sure droplet has been assigned an IP before trying to collect it

  # Get the IP of the new droplet
  RES=`curl -s -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        https://api.digitalocean.com/v2/droplets/$DROPLET_ID`
  DROPLET_IP=`echo $RES | jq -r '.droplet.networks.v4[] | select(.type=="public") | .ip_address'`
  echo Droplet IP: $DROPLET_IP

  # Need to wait to allow the machine to finish fully provisioning itself and letting SSH come up...
  echo "Waiting 90 seconds..."
  sleep 90

  # Add ssh keys to known_hosts
  ssh-keyscan -H $DROPLET_IP 2>/dev/null >> ~/.ssh/known_hosts

  # Pull image
  echo -n "Pulling docker image... "
  ssh root@$DROPLET_IP "docker pull $CONTAINER_NAME" > /dev/null
  echo "Done!"

  # Run image
  echo -n "Starting container... "
  CONTAINER_ID=`ssh root@$DROPLET_IP "docker run --rm -d -p 80:80 $CONTAINER_NAME"`
  echo "Done!"
  echo $CONTAINER_ID
else
  # SERVER IS DOWN
  echo "DOWN!"
fi