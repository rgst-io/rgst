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

local argo = import '../../../libs/argocd.libsonnet';

argo.HelmApplication(
  chart='overseerr',
  repoURL='https://k8s-at-home.com/charts',
  version='5.4.2',
  values={
    nodeSelector: {
      'kubernetes.io/hostname': 'shino',
    },
    image: {
      tag: '1.31.0',
    },
    env: {
      TZ: 'America/Los_Angeles',
    },
    ingress: {
      main: {
        enabled: true,
        annotations: {
          'cert-manager.io/cluster-issuer': 'main',
          // Ensure client IPs from Cloudflare are preserved
          'nginx.ingress.kubernetes.io/configuration-snippet': 'real_ip_header CF-Connecting-IP;',
        },
        hosts: [{
          host: 'media.rgst.io',
          paths: [{
            path: '/',
            pathType: 'ImplementationSpecific',
          }],
        }],
        ingressClassName: 'nginx',
        tls: [{
          hosts: ['media.rgst.io'],
          secretName: 'media-rgst-io-tls',
        }],
      },
    },
    persistence: {
      config: {
        enabled: true,
        size: '1Gi',
      },
    },
  }
)
