// Copyright (C) 2024 Jared Allard <jared@rgst.io>
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

local argo = import '../../libs/argocd.libsonnet';
local secrets = import '../../libs/external-secrets.libsonnet';
local k = import '../../libs/k.libsonnet';

local name = 'cert-manager';

local all = {
  // https://artifacthub.io/packages/helm/cert-manager/cert-manager
  application: argo.HelmApplication(
    chart=name,
    repoURL='https://charts.jetstack.io',
    version='v1.13.3',
    values={
      installCRDs: true,
    },
  ),
  cluster_issuer: k._Object('cert-manager.io/v1', 'ClusterIssuer', 'main') {
    spec: {
      acme: {
        email: 'jared@rgst.io',
        server: 'https://acme-v02.api.letsencrypt.org/directory',
        privateKeySecretRef: {
          name: 'main-issuer-key',
        },
        solvers: [{
          dns01: {
            cloudflare: {
              email: 'jared@rgst.io',
              apiTokenSecretRef: {
                name: 'cloudflare-api-key',
                key: 'api-key',
              },
            },
          },
        }],
      },
    },
  },
  external_secret: secrets.ExternalSecret('cloudflare-api-key', name) {
    secret_store:: secrets.ClusterSecretStore('kubernetes'),
    target:: 'cloudflare-api-key',
    keys:: {
      'api-key': {
        remoteRef: {
          key: 'CLOUDFLARE_API_KEY',
        },
      },
    },
  },
};

k.List() { items_:: all }
