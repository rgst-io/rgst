#!/usr/bin/env bash
# Installs ArgoCD on a Kubernetes cluster. This is replaced
# by the ArgoCD application that is created later.
set -eo pipefail

cluster_name="$1"
config_cluster_domain="$2"
if [[ -z $cluster_name || -z $config_cluster_domain ]]; then
	echo "Usage: $0 <cluster_name> <config_cluster_domain>"
	exit 1
fi

tmpFile=$(mktemp)
trap 'rm -f $tmpFile' EXIT

jsonnet -V "cluster_name=$cluster_name" -V "config_cluster_domain=$config_cluster_domain" \
	./manifests/apps/default/argocd.jsonnet | yq -r .spec.source.helm.values >"$tmpFile"
kubectl create namespace argocd || true
helm repo add argo https://argoproj.github.io/argo-helm || true
helm install -f "$tmpFile" -n argocd argocd argo/argo-cd || helm upgrade -f "$tmpFile" -n argocd argocd argo/argo-cd

until kubectl get configmap -n argocd argocd-cm 2>/dev/null; do
	echo "Waiting for ArgoCD to be ready..."
	sleep 5
done

pemTmpFile=$(mktemp)
trap 'rm -f $pemTmpFile' EXIT

kubens argocd

if ! argocd repo list --core | grep -q rgst-io/rgst; then
	echo "Adding rgst-io/rgst repo to ArgoCD..."
	op document get "Github Application (rgst-io/argocd)" --output="$pemTmpFile"
	argocd repo add https://github.com/rgst-io/rgst --github-app-id 245660 --github-app-installation-id 31907708 --github-app-private-key-path "$pemTmpFile" --core
fi

if ! kubectl get secret -n external-secrets doppler-token-auth-api 2>/dev/null; then
	echo "Adding doppler secret"
	kubectl create secret generic --namespace external-secrets doppler-token-auth-api --from-literal dopplerToken="$(op read op://Private/oibj3d5llgsg64jdviaedmf5ty/credential)"
fi
