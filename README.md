# CS 183 Project

I self-host a few different services that I would like to remain online. Because the server is located at my house, problems such as power outages, accidentally turning off the server, or internet problems can cause these services to go offline.

To solve this problem, I will have a linux server setup that will monitor different services that I run. It will run minutely, either as a cron job or as a systemd service. When it detects any of the services are offline, it should automatically rent a server from a service such as DigitalOcean and provision it to have Docker installed. All of my projects run in containers, so the program should be able to get the container(s) running on the new system. My domain’s DNS (provided through Cloudflare) will also need to be updated in order to point towards the new server. Once the program determines my home’s network is back online, it will be responsible for destroying rented servers and changing DNS back to the original addresses.

## Deliverables

- [ ] Setup server to check if service is online and responsive
- [ ] If server is down, use DigitalOcean’s API to rent a server and provision with Docker
- [ ] Use new system to pull Docker and run docker containers
- [ ] Update Cloudflare DNS to point to new machine
- [ ] Detects when my home network comes back online, destroys DigitalOcean instance, and revert DNS.
