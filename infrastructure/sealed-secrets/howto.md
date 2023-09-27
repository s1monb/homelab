# How to use sealed secrets

First, create the wanted `secret.yaml`-file. Please not that the data needs to be base64-encoded.

```bash
kubectl create secret generic mysecret --dry-run=client --from-literal username=simon --from-literal password=test --output yaml > secret.yaml
```

This will generate a secret.yaml file with a secret named "mysecret"

Then run in the folder with the secet:

```bash
cat secret.yaml | kubeseal --controller-namespace kube-system --controller-name sealed-secrets --format yaml | sed '$d'  > sealed-secret.yaml
```

*`sed '$d'` is used to remove the trailing `---` kubeseal leaves behind.*

## Disaster Recovery

See how you can make sure you dont loose you secrets [here](https://blog.knoldus.com/using-sealed-secrets-in-kubernetes/#disaster-recovery-for-sealed-secrets).

## Updating and Scoping

Here is a more in-depth usage guide. [Link to sealed secret github](https://github.com/bitnami-labs/sealed-secrets#usage)
