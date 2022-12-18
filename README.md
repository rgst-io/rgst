# rgst

Kubernetes manifests for the rgst cloud. Currently backed by ArgoCD.

## Bootstrap

Add the cluster to `clusters.yaml`, providing the cloud provider as necessary. Then run the following:

```bash
go run ./cmd/rgst <clusterName>
```

### External-secrets

**Token URL**: <https://dashboard.doppler.com/workplace/fcf6a8b5edaff57804d8/projects/mstdn-satania-social/configs/prd/access>

```bash
HISTIGNORE='*kubectl*' kubectl create secret generic --namespace external-secrets doppler-token-auth-api --from-literal dopplerToken="dp.st.xxxx"
```

## License

GPL-3.0
