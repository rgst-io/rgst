// Copyright (C) 2022 Jared Allard <jared@rgst.io>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

local cluster_name = std.extVar('cluster_name');

local argo = import '../../libs/argocd.libsonnet';
local secrets = import '../../libs/external-secrets.libsonnet';
local k = import '../../libs/k.libsonnet';

local all = {
  application: argo.HelmApplication(
    chart='external-dns',
    repoURL='https://kubernetes-sigs.github.io/external-dns/',
    version='1.12.0',
    install_namespace='kube-system',
    values={
      txtOwnerId: cluster_name,
      provider: 'cloudflare',
      env: [
        {
          name: 'CF_API_KEY',
          valueFrom: {
            secretKeyRef: {
              name: 'external-dns',
              key: 'cloudflare-api-key',
            },
          },
        },
        {
          name: 'CF_API_EMAIL',
          valueFrom: {
            secretKeyRef: {
              name: 'external-dns',
              key: 'cloudflare-api-email',
            },
          },
        },
      ],
    },
  ),
  external_secret: secrets.ExternalSecret('external-dns', 'kube-system') {
    secret_store:: secrets.ClusterSecretStore('kubernetes'),
    target:: 'external-dns',
    keys:: {
      'cloudflare-api-key': {
        remoteRef: {
          key: 'CLOUDFLARE_API_KEY',
        },
      },
      'cloudflare-api-email': {
        remoteRef: {
          key: 'CLOUDFLARE_API_EMAIL',
        },
      },
    },
  },
};

k.List() { items_:: all }
