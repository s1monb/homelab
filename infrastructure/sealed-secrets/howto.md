# How to use sealed secrets

First, create the wanted `secret.yaml`-file.

Then run in the folder with the secet:

```bash
cat secret.yaml | kubeseal \
--controller-namespace kube-system \
--controller-name sealed-secrets-controller \
--format yaml \
> sealed-secret.yaml
```

## Disaster Recovery

See how you can make sure you dont loose you secrets [here](https://blog.knoldus.com/using-sealed-secrets-in-kubernetes/#disaster-recovery-for-sealed-secrets).

## Updating and Scoping

Here is a more in-depth usage guide. [Link to sealed secret github](https://github.com/bitnami-labs/sealed-secrets#usage)
