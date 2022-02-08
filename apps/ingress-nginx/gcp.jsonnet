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

local argo = import '../../libs/argocd.libsonnet';

argo.HelmApplication(
  chart='ingress-nginx',
  repoURL='https://kubernetes.github.io/ingress-nginx',
  version='4.4.0',
  release_name='gcp',
  values={
    controller: {
      // Use type NodePort because we'll create
      // a GCP LoadBalancer outside of the cluster.
      service: {
        type: 'NodePort',
      },

      // Run with 3 replicas to avoid downtime during upgrades
      replicaCount: 3,

      // Only deploy to GCP nodes
      nodeSelector: {
        'rgst.io/cloud': 'gcp',
      },
      tolerations: [{
        key: 'rgst.io/cloud',
        operator: 'Exists',
        effect: 'NoSchedule',
      }],

      // Set a custom IngressClass so that we can use this
      electionID: 'gcp',
      ingressClassResource: {
        enabled: true,
        default: false,
        name: 'gcp-nginx',
        controllerValue: 'k8s.io/gcp-ingress-nginx',
      },

      // Cloudflare Origin Pull
      extraVolumes: [{
        name: 'origin-pull-certificate',
        secret: {
          secretName: 'cloudflare-origin',
        },
      }],
      extraVolumeMounts: [{
        name: 'origin-pull-certificate',
        mountPath: '/var/lib/certificates/cloudflare',
      }],
      config: {
        'server-snippet': |||
          ssl_client_certificate /var/lib/certificates/cloudflare/cloudflare-origin.pem;
          ssl_verify_client on;
        |||,
      },
    },
  }
) + {
  metadata+: {
    name: 'ingress-nginx-gcp',
  },
}
