# CS183 Project
- [CS183 Project](#cs183-project)
- [Deliverables](#deliverables)
- [Setup](#setup)
  - [Prerequisites](#prerequisites)
  - [DigitalOcean Token](#digitalocean-token)
  - [Cloudflare Tokens](#cloudflare-tokens)
    - [API Token](#api-token)
    - [Zone ID](#zone-id)
    - [DNS IDs](#dns-ids)
  - [Ping Check](#ping-check)
- [Current Todos](#current-todos)

I self-host a few different services that I would like to remain online. Because the server is located at my house, problems such as power outages, accidentally turning off the server, or internet problems can cause these services to go offline.

To solve this problem, I will have a linux server setup that will monitor different services that I run. It will run minutely, either as a cron job or as a systemd service. When it detects any of the services are offline, it should automatically rent a server from a service such as DigitalOcean and provision it to have Docker installed. All of my projects run in containers, so the program should be able to get the container(s) running on the new system. My domain’s DNS (provided through Cloudflare) will also need to be updated in order to point towards the new server. Once the program determines my home’s network is back online, it will be responsible for destroying rented servers and changing DNS back to the original addresses.

# Deliverables

- [X] Setup server to check if service is online and responsive ( [6379562](https://github.com/emwjacobson/cs183_project/commit/6379562760bc9843d03b139e29d8e0c03323de7f) )
- [X] If server is down, use DigitalOcean’s API to rent a server and provision with Docker ( [09028df](https://github.com/emwjacobson/cs183_project/commit/09028df0c8a28fa09a24e9546bd0f428b922b0ef) )
- [X] Use new system to pull Docker and run docker containers ( [b3d9e88](https://github.com/emwjacobson/cs183_project/commit/b3d9e88e65a21e5c04ee5776369f55f4f927d7eb) )
- [ ] Update Cloudflare DNS to point to new machine (  )
- [ ] Detects when my home network comes back online, destroys DigitalOcean instance, and revert DNS. (  )

# Setup

## Prerequisites

The following packages must be installed.

`jq` - Bash Parsing of JSON

## DigitalOcean Token

In order to use script, you will need to generate an API Access Token. This can be done by visting the API page, viewing the "Tokens/Keys" tab, and clicking "Generate New Token". This page should also be available [here](https://cloud.digitalocean.com/account/api/tokens).

**Note the token, as it will be used in the setup.**

To make sure that the ping check program can remote into the rented machine, SSH keys need to be setup with DigitalOcean. This can be done by running `ssh-keygen` and uploading your public key to DigitalOcean under `Settings > Security`. After adding, you should get an SSH Fingerprint, **this is used in the next step**.

## Cloudflare Tokens

### API Token

The program also needs Cloudflare API Tokens in order to change DNS settings. These can be created [here](https://dash.cloudflare.com/profile/api-tokens). This script needs two permissions set, specifically `Zone.Zone Settings.Edit` and `Zone.DNS.Edit`.

**Save this token, as it's required later in the setup.**

### Zone ID

There are a few IDs that the script needs in order to change settings, the first one being your Zone ID. This one is easily accessable in the Right Column on the Overview page on your domain.

**Save this ID, as its required later in the setup.**

### DNS IDs

The next IDs needed are the DNS IDs. These cannot be viewed from your Cloudflare dashboard directly, and are most easily viewed by using Cloudflare's API. To make obtaining these IDs easier, there is an included helper script called `getids.sh`.

The `getids.sh` script requires 2 other tokens, `CLOUDFLARE_TOKEN` and `CLOUDFLARE_ZONE_ID`. These can either be manually set in the file, or by running the following. (Replacing the Xs with the respective tokens.)

`CLOUDFLARE_TOKEN=XXXX CLOUDFLARE_ZONE_ID=XXXX ./getids.sh | jq`

If everything was setup correctly some JSON should be printed relating to your current DNS records. Each record will have its respective `id` and `name`. For each DNS record you want the script to update, copy the `id` and `name` and add it to the list in the `check.sh` file.

As an example, I want 2 records to be updated for me, `emwj.dev` and `www.emwj.dev`. The start of my `check.sh` file should look as follows.

```
NUM_DNS_ENTRIES=2
CLOUDFLARE_DNS_NAMES=(emwj.dev www.emwj.dev)
CLOUDFLARE_DNS_IDS=(asdIDforEMWJdevdsa fooIDforWWWemwjDEVbar)
```

Optionally these can also be set as environmental variables.

## Ping Check

Ping Check runs on the machine that you want to use to monitor your application. It should obviously be outside of the network/machine that you want to monitor as if the internet or server is down, the ping check will probably be down too.

You need to set XXXX environmental variables: `PC_REMOTE_IP`, `DIGITALOCEAN_TOKEN`, `PC_SSH_FINGERPRINT`, `CLOUDFLARE_TOKEN`,

```
export PC_REMOTE_IP=your.ip.addr.ess
export DIGITALOCEAN_TOKEN=YoUrDiGiTaLoCeAnToKeN
export PC_SSH_FINGERPRINT=yo:ur:ss:hf:in:ge:rp:ri:nt
export CLOUDFLARE_TOKEN=YoUrClOuDfLaReToKeN
export CLOUDFLARE_ZONE_ID=YoUrClOuDfLaReZoNeId
```

This should be put in a `bashrc` file if running manually.

If the script is used from a crontab, then you will need to modify the crontab as follows.

```
# Add this environmental variable to the header of your crontab file
PC_REMOTE_IP=your.ip.addr.ess
DIGITALOCEAN_TOKEN=YoUrDiGiTaLoCeAnToKeN
PC_SSH_FINGERPRINT=yo:ur:ss:hf:in:ge:rp:ri:nt
CLOUDFLARE_TOKEN=YoUrClOuDfLaReToKeN

# Add script to the crontab
* * * * * /path/to/check.sh
```

# Current Todos

- Change DNS settings while waiting for server to finish provisioning
