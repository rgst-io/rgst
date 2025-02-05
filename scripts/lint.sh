#!/usr/bin/env bash
# Lints all jsonnet files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"

echo "Linting all jsonnet files"
for cluster_path in "$REPO_ROOT/manifests/apps/by-cluster"/*; do
  cluster_name=$(basename "$cluster_path")
  for file in "$cluster_path/"*.jsonnet; do
    file_name=$(basename "$file")
    echo " -> $cluster_name/$file_name"
    jsonnet-lint "$file"
    jsonnet "$file" |
      kubeconform -strict -schema-location default \
        -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
  done
done
