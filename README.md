# rgst

Kubernetes manifests for the rgst cloud. Currently backed by ArgoCD.

## Bootstrap

```bash
jsonnet ./apps/argocd.jsonnet | yq -r .spec.source.helm.values > values.yaml
helm install -f values.yaml -n argocd argocd argocd/argo-cd
argocd repo add https://github.com/rgst-io/rgst --github-app-id 245660 --github-app-installation-id 30025489 --github-app-private-key-path argocd-rgst**.pem --core
k create -f ./apps/rgst.yaml
```

### External-secrets

**Token URL**: <https://dashboard.doppler.com/workplace/fcf6a8b5edaff57804d8/projects/mstdn-satania-social/configs/prd/access>

```bash
HISTIGNORE='*kubectl*' kubectl create secret generic --namespace external-secrets doppler-token-auth-api --from-literal dopplerToken="dp.st.xxxx"
```

## License

GPL-3.0
