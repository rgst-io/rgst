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

local cluster_name = std.extVar('cluster_name');
local cluster_domain = std.extVar('config_cluster_domain');
local fqdn = '%s.%s' % [cluster_name, cluster_domain];
local argo = import '../../libs/argocd.libsonnet';

// https://artifacthub.io/packages/helm/argo/argo-cd
argo.HelmApplication(
  chart='argo-cd',
  repoURL='https://argoproj.github.io/argo-helm',
  version='7.3.3',
  values={
    global: {
      domain: fqdn,
    },

    configs: {
      params: {
        'server.insecure': true,
      },
    },

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
          memory: '256Mi',
          cpu: '300m',
        },
        limits: self.requests,
      },
    },

    server: {
      // We're only accessible via Cloudflare's Zero-Trust.
      extraArgs: ['--disable-auth'],
      resources: {
        requests: {
          memory: '256Mi',
          cpu: '500m',
        },
        limits: self.requests,
      },

      // Ingress Object
      ingress: {
        enabled: true,
        annotations: {
          'cert-manager.io/cluster-issuer': 'main',
          'nginx.ingress.kubernetes.io/ssl-passthrough': 'true',
          'nginx.ingress.kubernetes.io/backend-protocol': 'HTTPS',
        },
        ingressClassName: 'nginx',
        tls: true,
      },

      // Autoscaling
      autoscaling: {
        enabled: true,
        minReplicas: 2,
      },

      repoServer: {
        autoscaling: {
          enabled: true,
          minReplicas: 2,
        },
      },

      applicationSet: {
        replicaCount: 2,
      },
    },  // End Server Config
  },
  install_namespace='argocd',
) + {
  metadata+: {
    name: 'argocd',
  },
}
