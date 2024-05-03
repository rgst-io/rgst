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

local name = 'authentik';
local secName = name + '-custom';

local all = {

  namespace: k._Object('v1', 'Namespace', name) {},
  // https://artifacthub.io/packages/helm/goauthentik/authentik
  application: argo.HelmApplication(
    chart='authentik',
    repoURL='https://charts.goauthentik.io',
    version='2024.4.1',
    values={
      // Secrets come from here.
      global: {
        envFrom: [{ secretRef: { name: secName } }],
      },
      authentik: {
        // This sends anonymous usage-data, stack traces on errors and
        // performance data to sentry.io, and is fully opt-in
        error_reporting: {
          enabled: false,
        },

        // Postgres config
        postgresql: {
          // ruka.koi-insen.ts.net
          host: '100.109.240.128',
          port: 5432,
        },
      },
      server: {
        ingress: {
          enabled: true,
          ingressClassName: 'nginx',
          annotations: {
            'cert-manager.io/cluster-issuer': 'main',
            // Ensure client IPs from Cloudflare are preserved
            'nginx.ingress.kubernetes.io/configuration-snippet': 'real_ip_header CF-Connecting-IP;',
          },
          hosts: ['auth.rgst.io'],
          tls: [{
            secretName: 'auth-rgst-io',
            hosts: ['auth.rgst.io'],
          }],
        },
      },
      postgresql: {
        enabled: false,
      },
      redis: {
        enabled: true,
      },
    },
  ),
  external_secret: secrets.ExternalSecret(name, name) {
    keys:: {
      AUTHENTIK_SECRET_KEY: { remoteRef: { key: 'SECRET_KEY' } },
      AUTHENTIK_POSTGRESQL__PASSWORD: { remoteRef: { key: 'POSTGRES_PASSWORD' } },
    },
    secret_store:: $.doppler.secret_store,
    target:: secName,
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
