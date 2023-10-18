# How to set up network policies for new deployments/workloads

This cluster is set up to deny all network-traffic by default. To enable traffic from both inside or outside cluster, you have to set up a `CiliumNetworkPolicy`.

To do this, please refer to [this guide](https://docs.cilium.io/en/latest/security/policy/language/#endpoints-based).

## Example

You have a nginx-service that needs to be accesible from outside the cluster:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-nginx-from-outside # make descriptive name
spec:
  endpointSelector:
    matchLabels:
      app: nginx # These selectors use AND (must match all the labels)
  ingress:
  - fromEntities:
    - world # Outside cluster
  egress:
  - toEntities:
     - none # Unable to communicate to others
     # But can be reached and answer ofcourse.
```

Check out [this file](./infrastructure/cilium/allow-hubble.yaml) used to enable hubble-ui and hubble-relay to monitor network traffic in the cluster.
