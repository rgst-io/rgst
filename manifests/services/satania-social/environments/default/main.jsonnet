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

local corev1 = import 'corev1.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local k = import 'k.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local appsv1 = k.apps.v1;
local container = corev1.container;
local readinessProbe = container.readinessProbe;
local livenessProbe = container.livenessProbe;
local ingress = k.networking.v1.ingress;

local image = 'ghcr.io/glitch-soc/mastodon:edge';

local nodeSelector = {};
local tolerations = [];

{
  postgres: helm.template('postgres', '../../charts/postgres', {
    values: {
      tolerations: tolerations,
      nodeSelector: nodeSelector,
      storage: {
        requestedSize: '20Gi',
      },
      extraEnvSecrets: ['postgres'],
    },
  }),
  redis: helm.template('redis', '../../charts/redis', {
    values: {
      tolerations: tolerations,
      nodeSelector: nodeSelector,
    },
  }),
  config: {
    configmap: corev1.configMap.new('mastodon', import './config.jsonnet'),
    // fake secret for usage later
    secret:: corev1.secret.new('mastodon', {}),
  },
  ingress: ingress.new('mastodon') + {
    metadata+: {
      annotations+: {
        'cert-manager.io/cluster-issuer': 'main',
        // 200 Megabytes
        'nginx.ingress.kubernetes.io/proxy-body-size': '200m',
        // Ensure client IPs from Cloudflare are preserved
        'nginx.ingress.kubernetes.io/configuration-snippet': 'real_ip_header CF-Connecting-IP;',
      },
    },
    spec+: {
      ingressClassName: 'nginx',
      tls: [{
        hosts: ['mstdn.satania.social'],
        secretName: 'mstdn-satania-social',
      }],
      rules: [
        {
          host: 'mstdn.satania.social',
          http: {
            paths: [
              {
                path: '/',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: $.web.service.metadata.name,
                    port: {
                      number: $.web.service.spec.ports[0].port,
                    },
                  },
                },
              },
              {
                path: '/api/v1/streaming',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: $.streaming.service.metadata.name,
                    port: {
                      number: $.streaming.service.spec.ports[0].port,
                    },
                  },
                },
              },
            ],
          },
        },
      ],
    },
  },
  web: {
    local port = 3000,
    deployment: appsv1.deployment.new(
      name='web', replicas=2, containers=[
        container.new('web', image, [
          container.withCommand([
            'bash',
            '-c',
            'rm -f /mastodon/tmp/pids/server.pid; exec bundle exec rails s -p %s' % port,
          ]),
          {
            resources: {
              limits: self.requests,
              requests: {
                cpu: 1,
                memory: '2Gi',
              },
            },
          },
          container.withEnvFrom(corev1.envFromSource.configMapRef.withName($.config.configmap.metadata.name)),
          container.withEnvFromMixin(corev1.envFromSource.secretRef.withName($.config.secret.metadata.name)),
          readinessProbe.httpGet.new('/health', port),
          livenessProbe.httpGet.new('/health', port),
        ]),
      ],
    ) + appsv1.deployment.spec.template.spec.withNodeSelector(nodeSelector) + appsv1.deployment.spec.template.spec.withTolerations(tolerations),
    service: corev1.service.new(
      name='web',
      selector=$.web.deployment.spec.template.metadata.labels,
      ports=[{
        name: 'http',
        port: port,
        targetPort: port,
      }]
    ),
  },
  streaming: {
    local port = 4000,
    deployment: appsv1.deployment.new(name='streaming', replicas=2, containers=[
      container.new('streaming', image, [
        container.withCommand(['node', './streaming']),
        container.withEnvFrom(corev1.envFromSource.configMapRef.withName($.config.configmap.metadata.name)),
        container.withEnvFromMixin(corev1.envFromSource.secretRef.withName($.config.secret.metadata.name)),
        {
          resources: {
            limits: self.requests,
            requests: {
              cpu: 1,
              memory: '2Gi',
            },
          },
        },
        readinessProbe.httpGet.new('/api/v1/streaming/health', port),
        livenessProbe.httpGet.new('/api/v1/streaming/health', port),
      ]),
    ]) + appsv1.deployment.spec.template.spec.withNodeSelector(nodeSelector) + appsv1.deployment.spec.template.spec.withTolerations(tolerations),
    service: corev1.service.new(
      name='streaming',
      selector=$.streaming.deployment.spec.template.metadata.labels,
      ports=[{
        name: 'http',
        port: port,
        targetPort: port,
      }]
    ),
  },
  sidekig: {
    deployment: appsv1.deployment.new(name='sidekiq', replicas=1, containers=[
      container.new('sidekiq', image, [
        container.withCommand(['bundle', 'exec', 'sidekiq']),
        {
          resources: {
            limits: self.requests,
            requests: {
              cpu: 1,
              memory: '2Gi',
            },
          },
        },
        container.withEnvFrom(corev1.envFromSource.configMapRef.withName($.config.configmap.metadata.name)),
        container.withEnvFromMixin(corev1.envFromSource.secretRef.withName($.config.secret.metadata.name)),
        readinessProbe.exec.withCommand(['bash', '-c', "ps aux | grep '[s]idekiq\\ 6' || false"]),
        livenessProbe.exec.withCommand(['bash', '-c', "ps aux | grep '[s]idekiq\\ 6' || false"]),
      ]),
    ]) + appsv1.deployment.spec.template.spec.withNodeSelector(nodeSelector) + appsv1.deployment.spec.template.spec.withTolerations(tolerations),
  },
}
