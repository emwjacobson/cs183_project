#!/bin/bash

# set -x

NUM_DNS_ENTRIES=2
CLOUDFLARE_DNS_NAMES=(emwj.dev www.emwj.dev)
CLOUDFLARE_DNS_IDS=(asdIDforEMWJdevdsa fooIDforWWWemwjDEVbar)

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
ping -c 1 $PC_REMOTE_IP >> recovery.log 2>&1

if [ $? -eq 0 ]; then
  # SERVER IS UP
  echo "UP!"

  # Check to see if we have a droplet running
  if [ -f ".pc_recovery" ]; then
    # We have a server already rented, or in the process of being rented
    echo "Server already rented"
    LINES=`wc -l < .pc_recovery`
    if [ $LINES -eq 3 ]; then
      # If there are 3 lines, then we know recovery has fully completed # TODO: Change this in future
      read -d'\n' DROPLET_ID DROPLET_IP < .pc_recovery
      echo -n "Deleting droplet $DROPLET_ID at $DROPLET_IP... "
      RES=`curl -s -X DELETE \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
      https://api.digitalocean.com/v2/droplets/$DROPLET_ID`;
      rm .pc_recovery
      echo "Done"

      echo -n "Restoring DNS records... "
      curl -X PATCH \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type:application/json" \
        -d "{\"value\": \"strict\"}" \
        "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/ssl" >> recovery.log 2>&1

      for i in `seq 0 $(expr $NUM_DNS_ENTRIES - 1)`; do
        curl -X PUT \
          -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
          -H "Content-Type:application/json" \
          -d "{\"type\": \"A\", \"name\": \"${CLOUDFLARE_DNS_NAMES[$i]}\", \"content\": \"$PC_REMOTE_IP\", \"ttl\": 1, \"proxied\": true}" \
          "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/${CLOUDFLARE_DNS_IDS[$i]}" >> recovery.log 2>&1
      done
      echo "Done!"
    else
      # If there are not 3 lines, then recovery is still in progress, do nothing
      echo "Recovery still in progress, need to wait for completion before stopping..."
    fi
  else
    # No server is rented, service is up. This is the situation we should be in 99.9% of the time :^)
    echo "Nothing to do..."
  fi
else
  # SERVER IS DOWN
  echo "DOWN!"

  # Check to see if we have a droplet running
  if [ -f ".pc_recovery" ]; then
    # Droplet is running. This means our server is down, and this script has already setup a droplet to replace it
    echo "Problem already solved"
  else
    # Service is down and droplet does not exist, so lets fix it!
    echo "Attempting recovery..."

    # Rent the machine and get its droplet ID
    RES=`curl -s -X POST \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
          -d "$DATA" \
          https://api.digitalocean.com/v2/droplets`;
    DROPLET_ID=$(echo $RES | jq '.droplet.id')
    echo Droplet ID: $DROPLET_ID
    echo $DROPLET_ID > .pc_recovery

    sleep 20 # Need to make sure droplet has been assigned an IP before trying to collect it

    # Get the IP of the new droplet
    RES=`curl -s -X GET \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
          https://api.digitalocean.com/v2/droplets/$DROPLET_ID`
    DROPLET_IP=`echo $RES | jq -r '.droplet.networks.v4[] | select(.type=="public") | .ip_address'`
    echo Droplet IP: $DROPLET_IP
    echo $DROPLET_IP >> .pc_recovery

    echo -n "Updating DNS records... "
    curl -X PATCH \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type:application/json" \
        -d "{\"value\": \"flexible\"}" \
        "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/ssl" >> recovery.log 2>&1

    for i in `seq 0 $(expr $NUM_DNS_ENTRIES - 1)`; do
      curl -X PUT \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type:application/json" \
        -d "{\"type\": \"A\", \"name\": \"${CLOUDFLARE_DNS_NAMES[$i]}\", \"content\": \"$DROPLET_IP\", \"ttl\": 1, \"proxied\": true}" \
        "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/${CLOUDFLARE_DNS_IDS[$i]}" >> recovery.log 2>&1
    done
    echo "Done!"

    # Need to wait to allow the machine to finish fully provisioning itself and letting SSH come up...
    echo -n "Waiting for droplet to boot..."
    while true; do
        RES=`curl -s -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        https://api.digitalocean.com/v2/droplets/$DROPLET_ID`

        STATUS=$(echo $RES | jq -r '.droplet.status')

        if [ "$STATUS" == 'active' ]; then
          break
        fi
        echo -n '.'
        sleep 5
    done
    echo "Done!"
    sleep 20

    # Add ssh keys to known_hosts
    ssh-keyscan -H $DROPLET_IP 2>/dev/null >> ~/.ssh/known_hosts

    echo -n "Cloning portfolio... "
    ssh root@$DROPLET_IP "git clone https://github.com/emwjacobson/emwj.dev" >> recovery.log 2>&1
    echo "Done!"

    echo -n "Configuring and running docker-compose... "
    ssh root@$DROPLET_IP "sed -i \"s/MakeThisALongRandomStringForProduction/$(openssl rand -hex 25)/\" emwj.dev/docker-compose.yml; \
                         sed -i \"s/your.website.com,subdomain.website.com/emwj.dev,www.emwj.dev/\" emwj.dev/docker-compose.yml; \
                         sed -i 's/8081:80/80:80/' emwj.dev/docker-compose.yml; \
                         docker-compose -p portfolio -f emwj.dev/docker-compose.yml up --build -d;" >> recovery.log 2>&1
    echo "Done!"

    echo "DONE" >> .pc_recovery

  fi
fi