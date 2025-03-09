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
      ingress: {
        enabled: true,
        annotations: {
          'nginx.ingress.kubernetes.io/proxy-body-size': '512M',
          'cert-manager.io/cluster-issuer': 'main',
        },
        className: 'nginx',
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
      postgresql: { enabled: false },  // We use the shared Postgres instance.
      'postgresql-ha': { enabled: false },
      'redis-cluster': { enabled: false },
      redis: { enabled: true },
    },
  ),
  runner: k._Object('apps/v1', 'Deployment', name + '-runner', namespace) {
    spec: {
      replicas: 2,
      selector: { matchLabels: { app: name + '-runner' } },
      strategy: {
        type: 'Recreate',
      },
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
          restartPolicy: 'Always',
          volumes: [
            {
              name: 'docker-socket',
              emptyDir: {},
            },
            {
              name: 'runner-data',
              emptyDir: {},
            },
          ],
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
                'ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest',
              ],
              env: [
                {
                  name: 'RUNNER_NAME',
                  valueFrom: { fieldRef: { fieldPath: 'metadata.name' } },
                },
                {
                  name: 'RUNNER_SECRET',
                  valueFrom: { secretKeyRef: { name: $.external_secret.metadata.name, key: 'RUNNER_SECRET' } },
                },
                {
                  name: 'FORGEJO_INSTANCE_URL',
                  value: 'http://forgejo-http.forgejo.svc.cluster.local:3000',
                },
              ],
              resources: {
                limits: {
                  cpu: 4,
                  memory: '8Gi',
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
              image: 'docker:28.0.1-dind',
              command: ['dockerd'],
              args: ['-H', 'unix:///docker-socket/docker.sock'],
              securityContext: { privileged: true },
              restartPolicy: 'Always',  // sidecar
              volumeMounts: [{
                name: 'docker-socket',
                mountPath: '/docker-socket/',
              }],
            },
          ],
          containers: [{
            name: 'runner',
            image: 'code.forgejo.org/forgejo/runner:6.2.2',
            args: ['daemon'],
            volumeMounts: [
              {
                name: 'docker-socket',
                mountPath: '/var/run',
              },
              {
                name: 'runner-data',
                mountPath: '/data',
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
