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

local argo = import '../../../libs/argocd.libsonnet';
local secrets = import '../../../libs/external-secrets.libsonnet';
local k = import '../../../libs/k.libsonnet';

local name = 'forgejo';
local host = 'git.idlerealm.io';
local namespace = name;

local all = {
  namespace: k._Object('v1', 'Namespace', name) {},
  // https://artifacthub.io/packages/helm/forgejo-helm/forgejo
  helm_chart: argo.HelmApplication(
    app_name=name,
    install_namespace=namespace,
    chart='forgejo',
    repoURL='code.forgejo.org/forgejo-helm',
    version='11.0.1',
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
          server: {
            ROOT_URL: 'https://' + host,
          },
          service: {
            DISABLE_REGISTRATION: false,
            ALLOW_ONLY_EXTERNAL_REGISTRATION: true,
            REQUIRE_SIGNIN_VIEW: true,
            ENABLE_INTERNAL_SIGNIN: false,
            ENABLE_BASIC_AUTHENTICATION: false,
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
        existingSecret: $.external_secret.metadata.name,
      },
      persistence: {
        size: '1Ti',
      },
      ingress: {
        enabled: true,
        annotations: {
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
  external_secret: secrets.ExternalSecret(name + '-custom', name) {
    keys:: {
      key: { remoteRef: { key: 'OAUTH_CLIENT_ID' } },
      secret: { remoteRef: { key: 'OAUTH_CLIENT_SECRET' } },
      privateKey: { remoteRef: { key: 'SIGNING_SSH_PRIVATE_KEY' } },
      DATABASE_PASSWORD: { remoteRef: { key: 'DATABASE_PASSWORD' } },
      MAIL_PASSWORD: { remoteRef: { key: 'MAIL_PASSWORD' } },
    },
    secret_store:: $.doppler.secret_store,
    target:: name + '-custom',
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
