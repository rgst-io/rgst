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

## Virtual Clusters

Our current setup supports Virtual Clusters through [Loft]. To create one, do the following:

1. Go to https://loft.rgst.io
2. Authenticate with your credentials
3. Create a vcluster
4. Connect through the [loft CLI]

You now have a [vcluster] which is basically a Kubernetes cluster that shares the compute
of the underlying host.

### Ingresses

Ingresses are synced to the host cluster and use the provided ingress controller. As such
you'll need to configure your DNS records to point to a specific address:

* `CNAME wan.rgst.io`
* TLS is required.

From there you should be access your resource.

### TLS

`cert-manager` is able to be used by default, simply create issuers and certificate objects
or use the automatic certificate management. See the [cert-manager] docs for more information.

## License

GPL-3.0

[Loft]: https://loft.sh
[loft CLI]: https://loft.sh/docs/getting-started/install
[vcluster]: https://www.vcluster.com/docs/v0.19
[cert-manager]: https://cert-manager.io/docs/tutorials/acme/nginx-ingress/#step-4---deploy-an-example-service
