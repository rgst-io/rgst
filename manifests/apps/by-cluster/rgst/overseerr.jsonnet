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

argo.HelmApplication(
  app_name='overseerr',
  chart='app-template',
  repoURL='https://bjw-s.github.io/helm-charts/',
  version='2.4.0',
  values={
    controller: {
      main: {
        image: {
          repository: 'ghcr.io/sct/overseerr',
          tag: '1.33.2',
        },
        env: {
          TZ: 'America/Los_Angeles',
        },
      },
    },
    pod: {
      nodeSelector: {
        'kubernetes.io/hostname': 'shino',
      },
    },
    ingress: {
      main: {
        enabled: true,
        annotations: {
          'cert-manager.io/cluster-issuer': 'main',
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
  },
)
