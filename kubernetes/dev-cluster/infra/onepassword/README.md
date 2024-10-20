# One Password controller

We first need to add the secrets to the cluster before onepassword can handle these on behalf of itself.

Fetch the credentials from this [link](https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow)

```bash
kubectl create secret generic op-credentials --from-file=./1password-credentials.json

kubectl create secret generic onepassword-token --from-literal=toke=YOUR_TOKEN
```
