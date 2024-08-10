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

local argo = import '../../../libs/argocd.libsonnet';
local secrets = import '../../../libs/external-secrets.libsonnet';
local k = import '../../../libs/k.libsonnet';

local name = 'loft';

local hostname = 'loft.rgst.io';

local all = {
  local configSecretsName = '%s-config-secrets' % name,
  namespace: k._Object('v1', 'Namespace', name) {},
  // https://artifacthub.io/packages/helm/loft/loft
  application: argo.HelmApplication(
    chart='loft',
    repoURL='https://charts.loft.sh',
    version='3.4.9',
    values={
      admin: {
        create: false,
      },
      affinity: {
        nodeAffinity: {
          requiredDuringSchedulingIgnoredDuringExecution: {
            nodeSelectorTerms: [{
              matchExpressions: [{
                key: 'kubernetes.io/arch',
                operator: 'In',
                values: ['amd64'],
              }],
            }],
          },
        },
      },
      config: {
        audit: {
          enabled: true,
        },
        auth: {
          oidc: {
            issuerUrl: 'https://auth.rgst.io',
            clientId: '$OIDC_CLIENT_ID',
            clientSecret: '$OIDC_CLIENT_SECRET',
            redirectURI: 'https://%s/auth/oidc/callback' % hostname,
          },
        },
        loftHost: hostname,
        devPodSubDomain: '*-%s' % hostname,
      },
      envValueFrom: {
        OIDC_CLIENT_ID: { secretKeyRef: { name: configSecretsName, key: 'OIDC_CLIENT_ID' } },
        OIDC_CLIENT_SECRET: { secretKeyRef: { name: configSecretsName, key: 'OIDC_CLIENT_SECRET' } },
      },
      ingress: {
        host: hostname,
        enabled: true,
        annotations: {
          'cert-manager.io/cluster-issuer': 'main',
        },
        tls: {
          enabled: true,
          secret: 'loft-tls',
        },
      },
      certIssuer: {
        create: false,
      },
    },
  ),
  external_secret: secrets.ExternalSecret(name, name) {
    all_keys:: true,
    secret_store:: $.doppler.secret_store,
    target:: configSecretsName,
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
