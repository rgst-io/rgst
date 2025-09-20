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

// NOTE: We're using a single cluster again for now.
//
// local cluster_name = std.extVar('cluster_name');
// local cluster_domain = std.extVar('config_cluster_domain');
// local fqdn = '%s.%s' % [cluster_name, cluster_domain];
local fqdn = 'argocd.koi-insen.ts.net';

local argo = import '../../../vendor/jsonnet-libs/argocd.libsonnet';
local secrets = import '../../../vendor/jsonnet-libs/external-secrets.libsonnet';
local k = import '../../../vendor/jsonnet-libs/k.libsonnet';

local name = 'argocd';

// https://artifacthub.io/packages/helm/argo/argo-cd
local all = {
  application: argo.HelmApplication(
    chart='argo-cd',
    repoURL='https://argoproj.github.io/argo-helm',
    version='8.5.3',
    values={
      global: {
        domain: fqdn,
      },

      configs: {
        cm: {
          'admin.enabled': 'false',
          'oidc.config': std.manifestYamlDoc({
            name: 'Authentik',
            issuer: 'https://auth.rgst.io/application/o/argocd/',
            clientID: '$oidc:OIDC_CLIENT_ID',
            clientSecret: '$oidc:OIDC_CLIENT_SECRET',
          }),
        },
        rbac: {
          'policy.csv': 'g, all, role:admin',
        },
      },

      // We configure SSO through the native OIDC support.
      dex: { enabled: false },

      redis: {
        resources: {
          requests: {
            memory: '256Mi',
            cpu: '100m',
          },
          limits: self.requests,
        },
      },

      controller: {
        replicas: 1,
      },

      repoServer: {
        resources: {
          requests: {
            memory: '512Mi',
            cpu: '1',
          },
          limits: self.requests,
        },
        autoscaling: {
          enabled: true,
          minReplicas: 2,
        },
      },

      server: {
        resources: {
          requests: {
            memory: '512Mi',
            cpu: '1',
          },
          limits: self.requests,
        },

        // Ingress Object
        ingress: {
          enabled: true,
          hostname: 'argocd',
          ingressClassName: 'tailscale',
          tls: true,
        },

        // Autoscaling
        autoscaling: {
          enabled: true,
          minReplicas: 1,
        },

        applicationSet: {
          replicaCount: 1,
        },
      },  // End Server Config
    },
    install_namespace='argocd',
  ) + {
    metadata+: {
      name: 'argocd',
    },
  },
  external_secret: secrets.ExternalSecret(name, name) {
    all_keys:: true,
    secret_store:: $.doppler.secret_store,
    target:: 'oidc',
  } {
    spec+: {
      target+: {
        template+: {
          metadata+: {
            labels+: {
              'app.kubernetes.io/part-of': 'argocd',
            },
          },
        },
      },
    },
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
