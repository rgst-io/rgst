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
  chart='portainer',
  repoURL='https://portainer.github.io/k8s/',
  version='1.0.38',
  values={
    enterpriseEdition: {
      enabled: true,
    },
    service: {
      type: 'ClusterIP',
    },
    tls: {
      force: true,
    },
    ingress: {
      enabled: true,
      ingressClassName: 'nginx',
      annotations: {
        'cert-manager.io/cluster-issuer': 'main',
        'nginx.ingress.kubernetes.io/backend-protocol': 'HTTPS',
      },
      hosts: [{
        host: 'portainer.rgst.io',
        paths: [{
          path: '/',
        }],
      }],
    },
  }
)
