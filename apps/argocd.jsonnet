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

local argo = import '../libs/argocd.libsonnet';

argo.HelmApplication(
  chart='argo-cd',
  repoURL='https://argoproj.github.io/argo-helm',
  version='5.16.2',
  values={
    'redis-ha': {
      enabled: true,
    },

    controller: {
      replicas: 1,
    },

    repoServer: {
      volumes: [
        {
          name: 'custom-tools',
          emptyDir: {},
        },
      ],
      initContainers: [
        {
          name: 'download-tools',
          image: 'curlimages/curl',
          command: [
            'sh',
            '-ec',
          ],
          args: [  // Using curl to fetch both Tanka and Jsonnet-bundler
            'export ARCH=$(uname -m); if [ "$ARCH" == "x86_64" ]; then ARCH="amd64"; fi; if [ "$ARCH" == "aarch64" ]; then ARCH="arm64"; fi; echo "Download jsonnet-bundler and tanka for $ARCH"; curl -Lo /custom-tools/jb https://github.com/jsonnet-bundler/jsonnet-bundler/releases/latest/download/jb-linux-"$ARCH" && curl -Lo /custom-tools/tk https://github.com/grafana/tanka/releases/download/v0.23.1/tk-linux-"$ARCH" && chmod +x /custom-tools/tk && chmod +x /custom-tools/jb',
          ],
          volumeMounts: [
            {
              mountPath: '/custom-tools',
              name: 'custom-tools',
            },
          ],
        },
      ],
      volumeMounts: [
        {
          mountPath: '/usr/local/bin/jb',  // Mount jb
          name: 'custom-tools',
          subPath: 'jb',
        },
        {
          mountPath: '/usr/local/bin/tk',  // Mount tk
          name: 'custom-tools',
          subPath: 'tk',
        },
      ],
    },

    server: {
      // We're only accessible via Cloudflare's Zero-Trust.
      extraArgs: ['--disable-auth'],

      config: {
        configManagementPlugins: std.manifestYamlDoc([{
          name: 'tanka',
          init: {
            command: ['sh', '-c'],
            args: ['jb install && tk tool charts vendor'],
          },
          generate: {
            command: ['sh', '-c'],
            args: ['tk show environments/default --dangerous-allow-redirect'],
          },
        }]),
      },

      // Ingress Object
      ingress: {
        enabled: true,
        https: true,
        annotations: {
          'cert-manager.io/cluster-issuer': 'main',
          'nginx.ingress.kubernetes.io/ssl-passthrough': 'true',
          'nginx.ingress.kubernetes.io/backend-protocol': 'HTTPS',
        },
        ingressClassName: 'nginx',
        hosts: ['argocd.rgst.io'],
        tls: [{
          secretName: 'argocd-secret',
          hosts: ['argocd.rgst.io'],
        }],
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
