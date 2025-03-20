// Copyright (C) 2025 Jared Allard <jared@rgst.io>
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

local argo = import '../../../../vendor/jsonnet-libs/argocd.libsonnet';
local secrets = import '../../../../vendor/jsonnet-libs/external-secrets.libsonnet';
local k = import '../../../../vendor/jsonnet-libs/k.libsonnet';

local name = 'forgejo';
local host = 'git.rgst.io';
local namespace = name;

local all = {
  namespace: k._Object('v1', 'Namespace', name) {},
  // https://artifacthub.io/packages/helm/forgejo-helm/forgejo
  helm_chart: argo.HelmApplication(
    app_name=name,
    install_namespace=namespace,
    //! renovate datasource=docker
    chart='forgejo',
    repoURL='code.forgejo.org/forgejo-helm',
    version='11.0.3',
    values={
      nodeSelector: {
        'kubernetes.io/hostname': 'ruka',
      },
      gitea: {
        oauth: [{
          name: 'Authentik',
          provider: 'openidConnect',
          autoDiscoverUrl: 'https://auth.rgst.io/application/o/forgejo/.well-known/openid-configuration',
          existingSecret: $.external_secret.metadata.name,
        }],
        config: {
          actions: {
            DEFAULT_ACTIONS_URL: 'https://github.com',
          },
          admin: {
            DEFAULT_EMAIL_NOTIFICATIONS: 'onmention',
            SEND_NOTIFICATION_EMAIL_ON_NEW_USER: true,
          },
          database: {
            DB_TYPE: 'postgres',
            HOST: '100.109.240.128',  // ruka.koi-insen.ts.net
            NAME: 'forgejo',
            USER: self.NAME,
            SCHEMA: 'forgejo',
          },
          mailer: {
            ENABLED: true,
            FROM: 'forgejo@rgst.io',
            PROTOCOL: 'smtps',
            SMTP_ADDR: 'smtp.mailgun.org',
            SMTP_PORT: 465,
            USER: 'forgejo@rgst.io',
          },
          'repository.pull-requests': { DEFAULT_MERGE_STYLE: 'squash', DEFAULT_UPDATE_STYLE: 'rebase' },
          'repository.signing': {
            SIGNING_KEY: '76193178098A55D00D388D48C969F001BABC0EE1',
            SIGNING_NAME: 'git.rgst.io Signing Key',
            SIGNING_EMAIL: 'forgejo@rgst.io',
            INITIAL_COMMIT: 'always',
            CRUD_ACTIONS: 'always',
            WIKI: 'never',
            MERGES: 'always',
          },
          server: {
            ROOT_URL: 'https://' + host,
            DISABLE_SSH: true,
            ENABLE_REVERSE_PROXY_AUTHENTICATION: false,
          },
          service: {
            DISABLE_REGISTRATION: false,
            ALLOW_ONLY_EXTERNAL_REGISTRATION: true,
            REQUIRE_SIGNIN_VIEW: false,
            ENABLE_INTERNAL_SIGNIN: false,
            ENABLE_BASIC_AUTHENTICATION: false,
            ENABLE_NOTIFY_MAIL: true,
          },
        },
        additionalConfigFromEnvs: [
          {
            name: 'FORGEJO__DATABASE__PASSWD',
            valueFrom: { secretKeyRef: {
              name: $.external_secret.metadata.name,
              key: 'DATABASE_PASSWORD',
            } },
          },
          {
            name: 'FORGEJO__MAILER__PASSWD',
            valueFrom: { secretKeyRef: {
              name: $.external_secret.metadata.name,
              key: 'MAIL_PASSWORD',
            } },
          },
        ],
      },
      signing: {
        enabled: true,
        existingSecret: $.external_secret.metadata.name,
      },
      persistence: {
        size: '1Ti',
      },
      ingress: { enabled: false },  // Managed by anubis
      postgresql: { enabled: false },  // We use the shared Postgres instance.
      'postgresql-ha': { enabled: false },
      'redis-cluster': { enabled: false },
      redis: { enabled: true, master: { resourcesPreset: 'medium' } },
    },
  ),

  anubis: k.Container {
    local selectors = {
      'app.kubernetes.io/instance': 'anubis',
      'app.kubernetes.io/name': 'anubis',
    },
    deployment: k._Object('apps/v1', 'Deployment', 'anubis', namespace) {
      metadata+: {
        labels: selectors,
      },
      spec: {
        replicas: 2,
        selector: { matchLabels: selectors },
        template: {
          metadata: { labels: selectors },
          spec: {
            containers: [{
              name: 'main',
              image: 'ghcr.io/techarohq/anubis:v1.13.0',
              env: k.envList({
                BIND: ':8080',
                DIFFICULTY: '5',
                METRICS_BIND: ':9090',
                SERVE_ROBOTS_TXT: 'true',
                TARGET: 'http://forgejo-http.forgejo.svc.cluster.local:3000',
              }),
              resources: {
                requests: {
                  cpu: '500m',
                  memory: '512Mi',
                },
                limits: self.requests,
              },
              ports: [{ name: 'http', containerPort: 8080 }],
              securityContext: {
                runAsUser: 1000,
                runAsGroup: self.runAsUser,
                runAsNonRoot: true,
                allowPrivilegeEscalation: false,
                capabilities: { drop: ['ALL'] },
                seccompProfile: { type: 'RuntimeDefault' },
              },
            }],
          },
        },
      },
    },
    service: k._Object('v1', 'Service', 'anubis', namespace) {
      spec: {
        ports: [{
          name: 'http',
          port: 8080,
          protocol: 'TCP',
          targetPort: 'http',
        }],
        selector: selectors,
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },
    ingress: k._Object('networking.k8s.io/v1', 'Ingress', name, namespace) {
      metadata+: {
        annotations+: {
          'cert-manager.io/cluster-issuer': 'main',
          'nginx.ingress.kubernetes.io/proxy-body-size': '0',  // Needed for docker images.
        },
      },
      spec: {
        ingressClassName: 'nginx',
        rules: [{
          host: host,
          http: {
            paths: [{
              backend: {
                service: {
                  name: 'anubis',
                  port: {
                    name: 'http',
                  },
                },
              },
              path: '/',
              pathType: 'Prefix',
            }],
          },
        }],
        tls: [{
          hosts: [host],
          secretName: std.strReplace(host, '.', '-'),
        }],
      },
    },
  },

  runner_config: k.ConfigMap(name + '-runner-config', namespace) {
    data_:: {
      'config.yaml': std.manifestYamlDoc({
        runner: {
          // Generated by the registration init container.
          file: '.runner',
          capacity: 2,
        },
        container: {
          valid_volumes: ['/run/docker/docker.sock'],
          force_pull: true,
          // Expose our socket into the container.
          options: '-v /run/docker/docker.sock:/var/run/docker.sock:ro',
        },
      }),
    },
  },
  runner: k._Object('apps/v1', 'StatefulSet', name + '-runner', namespace) {
    spec: {
      replicas: 1,
      selector: { matchLabels: { app: name + '-runner' } },
      serviceName: name + '-runner',
      updateStrategy: { type: 'RollingUpdate' },
      template: {
        metadata: {
          labels: {
            app: $.runner.spec.selector.matchLabels.app,
          },
        },
        spec: {
          nodeSelector: {
            'kubernetes.io/hostname': 'mocha',
          },
          volumes: [
            { name: name, emptyDir: {} }
            for name in ['dind-sock', 'dind-home', 'runner-data']
          ] + [{
            name: 'runner-config',
            configMap: {
              name: all.runner_config.metadata.name,
            },
          }],
          local dind_sock_dir = '/run/docker',
          local dind_sock = dind_sock_dir + '/docker.sock',
          initContainers: [
            {
              name: 'runner-register',
              image: 'code.forgejo.org/forgejo/runner:6.2.2',
              command: [
                'forgejo-runner',
                'register',
                '--no-interactive',
                '--token',
                '$(RUNNER_SECRET)',
                '--name',
                '$(RUNNER_NAME)',
                '--instance',
                '$(FORGEJO_INSTANCE_URL)',
                '--labels',
                'ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-24.04',
              ],
              env: k.envList({
                RUNNER_NAME: { fieldRef: { fieldPath: 'metadata.name' } },
                RUNNER_SECRET: { secretKeyRef: { name: $.external_secret.metadata.name, key: 'RUNNER_SECRET' } },
                FORGEJO_INSTANCE_URL: 'http://forgejo-http.forgejo.svc.cluster.local:3000',
              }),
              resources: {
                limits: {
                  cpu: 6,
                  memory: '12Gi',
                },
                requests: {
                  cpu: 2,
                  memory: '4Gi',
                },
              },
              volumeMounts: [{
                name: 'runner-data',
                mountPath: '/data',
              }],
            },
            {
              name: 'docker',
              image: 'docker:28.0.1-dind-rootless',
              args: [
                '--host',
                'unix://' + dind_sock,
              ],
              securityContext: {
                seccompProfile: { type: 'Unconfined' },
                appArmorProfile: { type: 'Unconfined' },
                privileged: true,
                runAsUser: 1000,
                runAsGroup: 1000,
              },
              restartPolicy: 'Always',  // sidecar
              volumeMounts: [
                {
                  name: 'dind-sock',
                  mountPath: dind_sock_dir,
                },
                {
                  name: 'dind-home',
                  mountPath: '/home/rootless',
                },
              ],
            },
          ],
          containers: [{
            name: 'runner',
            image: 'code.forgejo.org/forgejo/runner:6.2.2',
            command: ['forgejo-runner', 'daemon', '--config', 'config.yaml'],
            env: k.envList({
              DOCKER_HOST: 'unix:///run/docker/docker.sock',
            }),
            volumeMounts: [
              {
                name: 'dind-sock',
                mountPath: dind_sock_dir,
                readOnly: true,
              },
              {
                name: 'runner-data',
                mountPath: '/data',
              },
              {
                name: 'runner-config',
                mountPath: '/data/config.yaml',
                subPath: 'config.yaml',
                readOnly: true,
              },
            ],
          }],
        },
      },
    },
  },

  external_secret: secrets.ExternalSecret(name + '-custom', name) {
    keys:: {
      key: { remoteRef: { key: 'OAUTH_CLIENT_ID' } },
      secret: { remoteRef: { key: 'OAUTH_CLIENT_SECRET' } },
      privateKey: { remoteRef: { key: 'SIGNING_SSH_PRIVATE_KEY' } },
    } + {
      [k]: { remoteRef: { key: k } }
      for k in ['DATABASE_PASSWORD', 'MAIL_PASSWORD', 'RUNNER_SECRET']
    },
    secret_store:: $.doppler.secret_store,
    target:: name + '-custom',
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
