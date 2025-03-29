# Homelab

## TODO

- [ ] DDNS - Document the process of setting up a DDNS service with unifi
- [ ] Loadbalancing and ingress
  - [ ] Add loadbalancing to the homelab-network and point the WAN-IP
        towards the loadbalancer and then to towards a kubernetes ingress.

This is the repo for my 2-node homelab built on proxmox. It is primarily meant
to be a kubernetes testinglab, but I also use it to run certain applications
for my household.

> **Note:** There are a ton of paths you can to take when running you own
> infra- and own platform-layer in a homelab-environment. Because of this fact,
> it will be hard to make a homelab-repo so generic that it can fit all your
> needs as well as mine. However I have tried to make the parts/modules in this
> repo decoupled and *transposable*.

## Prerequisites

- Server(s) to install Proxmox on
- A working network with internet connection
- A whole lot of patience and a whole lot of time

## Getting started

1. [Install Proxmox](docs/proxmox/proxmox-installation.md)
2. [Setup DNS and certificates](docs/network-and-security/dns-and-certificates.md) <!-- markdownlint-disable-line MD013 -->

## Networking

See [docs/network-and-security/network-overview.md](docs/network-and-security/network-overview.md) <!-- markdownlint-disable-line MD013 # Link length != length -->

## Storage
