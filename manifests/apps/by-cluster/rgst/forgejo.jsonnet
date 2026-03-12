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

local nodes = {
  'control-plane': 'ruka',
  runners: [
    { node_name: 'mocha', arch: 'amd64' },
    { node_name: 'pikachu', arch: 'arm' },
  ],
};

local all = {
  namespace: k._Object('v1', 'Namespace', name) {},
  // https://artifacthub.io/packages/helm/forgejo-helm/forgejo
  helm_chart: argo.HelmApplication(
    app_name=name,
    install_namespace=namespace,
    //! renovate datasource=docker
    chart='forgejo',
    repoURL='code.forgejo.org/forgejo-helm',
    version='16.2.0',
    values={
      nodeSelector: {
        'kubernetes.io/hostname': nodes['control-plane'],
      },
      gitea: {
        admin: { username: '' },
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
            DISABLE_REGULAR_ORG_CREATION: true,
            SEND_NOTIFICATION_EMAIL_ON_NEW_USER: true,
          },
          cache: {
            ADAPTER: 'redis',
            HOST: 'redis://forgejo-valkey.forgejo.svc.cluster.local:6379/1',
          },
          database: {
            DB_TYPE: 'postgres',
            HOST: '100.109.240.128',  // ruka.koi-insen.ts.net
            NAME: 'forgejo',
            USER: self.NAME,
            SCHEMA: 'forgejo',
          },
          DEFAULT: {
            APP_NAME: 'git.rgst.io',
          },
          git: {
            GC_ARGS: '--aggressive --auto',
          },
          // https://forgejo.org/docs/next/admin/config-cheat-sheet/#git---timeout-settings-gittimeout
          'git.timeout': {
            MIGRATE: 60 * 60,  // 1 hour in seconds
          },
          repository: {
            // We limit users by default to be unable to create any
            // repos, orgs, and forks.
            //
            // If you're seeing this and would like access, reach out to
            // me :)
            MAX_CREATION_LIMIT: 0,
            ALLOW_FORK_WITHOUT_MAXIMUM_LIMIT: false,
          },
          queue: {
            TYPE: 'redis',
            CONN_STR: 'redis://forgejo-valkey.forgejo.svc.cluster.local:6379/0',
          },
          'repository.pull-requests': { DEFAULT_MERGE_STYLE: 'squash', DEFAULT_UPDATE_STYLE: 'rebase' },
          'repository.signing': {
            DEFAULT_TRUST_MODEL: 'committer',
            SIGNING_KEY: '76193178098A55D00D388D48C969F001BABC0EE1',
            SIGNING_NAME: 'git.rgst.io Signing Key',
            SIGNING_EMAIL: 'forgejo@rgst.io',
            INITIAL_COMMIT: 'always',
            CRUD_ACTIONS: 'always',
            WIKI: 'never',
            MERGES: 'always',
          },
          security: {
            PASSWORD_HASH_ALGO: 'argon2',
            PASSWORD_CHECK_PWN: true,
            GLOBAL_TWO_FACTOR_REQUIREMENT: 'admin',
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
          session: {
            PROVIDER: 'redis',
            PROVIDER_CONFIG: 'redis://forgejo-valkey.forgejo.svc.cluster.local:6379/2',
          },
          moderation: { enabled: true },
          mailer: {
            ENABLED: true,
            FROM: 'forgejo@rgst.io',
            PROTOCOL: 'smtps',
            SMTP_ADDR: 'smtp.mailgun.org',
            SMTP_PORT: 465,
            USER: 'forgejo@rgst.io',
          },
          oauth2_client: {
            ENABLE_AUTO_REGISTRATION: true,
            ACCOUNT_LINKING: 'disabled',
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
        size: $.gitea_pv.spec.capacity.storage,
        create: false,
        claimName: $.gitea_pvc.metadata.name,
      },
      ingress: {
        enabled: true,
        annotations: {
          // Docker image pushes need this to be disabled
          'nginx.ingress.kubernetes.io/proxy-body-size': '0',
          'cert-manager.io/cluster-issuer': 'main',
        },
        className: 'traefik',
        hosts: [{
          host: host,
          paths: [{
            path: '/',
            pathType: 'Prefix',
          }],
        }],
        tls: [{
          hosts: [host],
          secretName: std.strReplace(host, '.', '-'),
        }],
      },
    },
  ),

  gitea_pvc: k._Object('v1', 'PersistentVolumeClaim', 'forgejo-gitea-shared-storage', namespace) {
    spec: {
      storageClassName: '',
      accessModes: ['ReadWriteOnce'],
      resources: {
        requests: { storage: $.gitea_pv.spec.capacity.storage },
      },
      volumeName: $.gitea_pv.metadata.name,
    },
  },
  gitea_pv: k._Object('v1', 'PersistentVolume', 'forgejo-gitea-shared-storage') {
    spec: {
      storageClassName: '',
      capacity: {
        storage: '500Gi',
      },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      'local': { path: '/mnt/db/forgejo' },
      nodeAffinity: {
        required: {
          nodeSelectorTerms: [{ matchExpressions: [{
            key: 'kubernetes.io/hostname',
            operator: 'In',
            values: [nodes['control-plane']],
          }] }],
        },
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

  runners: k.Container {
    ['runner_%s' % runner.node_name]: k._Object('apps/v1', 'StatefulSet', name + '-runner' + '-' + runner.node_name, namespace) {
      local this = self,
      spec: {
        replicas: 1,
        selector: { matchLabels: { app: name + '-runner' + '-' + runner.node_name } },
        serviceName: name + '-runner',
        updateStrategy: { type: 'RollingUpdate' },
        template: {
          metadata: {
            labels: {
              app: this.spec.selector.matchLabels.app,
            },
          },
          spec: {
            nodeSelector: {
              'kubernetes.io/hostname': runner.node_name,
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
            local images = [
              { version: '24.04', latest: true },
            ],
            initContainers: [
              {
                name: 'runner-register',
                image: 'code.forgejo.org/forgejo/runner:12.7.1',
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
                ] + [
                  '--labels',
                  std.join(',', std.flattenArrays([
                    [
                      'ubuntu-%s%s:docker://ghcr.io/catthehacker/ubuntu:act-%s' % [image.version, if runner.arch == 'arm' then '-' + runner.arch else '', image.version],
                    ] + (
                      if image.latest then [
                        'ubuntu-latest%s:docker://ghcr.io/catthehacker/ubuntu:act-%s' % [if runner.arch == 'arm' then '-' + runner.arch else '', image.version],
                      ] else []
                    )
                    for image in images
                  ])),
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
                image: 'docker:29.3.0-dind',
                args: [
                  '--host',
                  'unix://' + dind_sock,
                ],
                securityContext: {
                  seccompProfile: { type: 'Unconfined' },
                  appArmorProfile: { type: 'Unconfined' },
                  privileged: true,
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
              {
                name: 'preload-docker-images',
                image: 'docker:29.3.0-dind',
                command: ['/bin/sh', '-ce'],
                env: k.envList({
                  DOCKER_HOST: 'unix:///run/docker/docker.sock',
                }),
                args: [
                  std.join(
                    ' && ',
                    [
                      'docker version',
                    ] + [
                      'docker pull ghcr.io/catthehacker/ubuntu:act-%s' % image.version
                      for image in images
                    ],
                  ),
                ],
                volumeMounts: [{
                  name: 'dind-sock',
                  mountPath: dind_sock_dir,
                  readOnly: true,
                }],
              },
            ],
            containers: [{
              name: 'runner',
              image: 'code.forgejo.org/forgejo/runner:12.7.1',
              command: ['forgejo-runner', 'daemon', '--config', 'config.yaml'],
              env: k.envList({
                DOCKER_HOST: 'unix:///run/docker/docker.sock',
              }),
              securityContext: { runAsUser: 0, runAsGroup: 0 },
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
    }
    for runner in nodes.runners
  },

  valkey_helm_chart: argo.HelmApplication(
    app_name=name + '-valkey',
    install_namespace=namespace,
    chart='valkey',
    repoURL='https://valkey.io/valkey-helm/',
    version='0.9.3',
    values={
      image: {
        repository: 'valkey/valkey',
        tag: '9.0.3',
      },
      dataStorage: {
        enabled: true,
        className: 'nfs-client',
        requestedSize: '20Gi',
      },
    }
  ),

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
