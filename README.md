# rgst

Kubernetes manifests for the rgst cloud. Currently backed by ArgoCD.

## Bootstrap

Add the cluster to `clusters.yaml`, providing the cloud provider as necessary. Then run the following:

```bash
go run ./cmd/rgst <clusterName>
```

### External-secrets

**Token URL**: <https://start.1password.com/open/i?a=MNCJX4OI3REGDJCZJ3D6Q24TNY&v=tnygvhl6hvfkrrpt35cj367a3a&i=oibj3d5llgsg64jdviaedmf5ty&h=my.1password.com>

```bash
HISTIGNORE='*kubectl*' kubectl create secret generic --namespace external-secrets doppler-token-auth-api --from-literal dopplerToken="dp.st.xxxx"
```

## License

GPL-3.0