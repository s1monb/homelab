# Network overview

## Wifi/Home networks

The home network is divided into two subnets: a private subnet and a guest
subnet. The private subnet is used for personal devices, while the guest
subnet is used for guests (du-uh). The guest subnet is isolated from the
private subnet as well as the homelab-network, but both subnets can access
the internet.

```mermaid
graph TD
    subgraph HomeNetwork ["Home Network<br>192.168.0.0/16"]
        subgraph Private [Private<br>192.168.0.0/24]
            private_devices[Private devices like phones, laptops,etc.]
        end
        subgraph Guest [Guest<br>192.168.127.0/24]
            gues_devices[Private devices like phones, laptops,etc.]
        end
    end
```

## Lab network

```mermaid
graph TD
    subgraph A [Homelab Network<br>10.0.0.0/8]
        subgraph B1 [Stable<br>10.0.0.0/16]
            subgraph C1 [Stable 01<br>10.0.0.0/24]
                subgraph pve_zone_01 [pve-zone-01]
                    pve_01[pve-01<br>10.0.0.21]
                    pve_02[pve-02<br>10.0.0.22]
                end
            end
        end

    end
```