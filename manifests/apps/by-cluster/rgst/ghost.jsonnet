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
local secrets = import '../../../libs/external-secrets.libsonnet';
local k = import '../../../libs/k.libsonnet';

local name = 'ghost';
local namespace = name;

local all = {
  application: argo.HelmApplication(
    chart='ghost',
    install_namespace=namespace,
    repoURL='https://groundhog2k.github.io/helm-charts',
    version='0.134.1',
    values={
      settings: {
        url: 'https://jaredallard.dev',
      },
      fullnameOverride: 'ghost-jaredallard',
      image: {
        repository: 'ghost',
        tag: '5.96.0-alpine',
      },
      ingress: {
        annotations: {
          'cert-manager.io/cluster-issuer': 'main',
          'kubernetes.io/ingress.class': 'nginx',
        },
        enabled: true,
        tls: [{
          hosts: ['jaredallard.dev'],
          secretName: 'jaredallard-dev-tls',
        }],
        hosts: [{
          host: 'jaredallard.dev',
          paths: [{
            path: '/',
            pathType: 'Prefix',
          }],
        }],
      },
      storage: {
        requestedSize: '15Gi',
        persistentVolumeClaimName: 'jaredallard-ghost',
      },
      externalDatabase: {
        type: 'mysql',
        host: '',
        user: '',
        password: '',
        database: '',
      },
      customAnnotations: {
        // Reload whenever our secret changes
        'reloader.stakater.com/auto': 'true',
      },
    },
  ) {
    spec+: {
      // Ignore the secret because external-secrets takes over it later.
      ignoreDifferences: [{
        group: '',
        kind: 'Secret',
        name: 'ghost-jaredallard',
        jsonPointers: [
          '/data',
          '/metadata',
        ],
      }],
      syncPolicy+: {
        syncOptions+: ['RespectIgnoreDifferences=true'],
      },
    },
  },
  pvc: k._Object('v1', 'PersistentVolumeClaim', name, namespace) {
    metadata+: {
      name: 'jaredallard-ghost',
    },
    spec: {
      accessModes: ['ReadWriteOnce'],
      resources: {
        requests: {
          storage: '20Gi',
        },
      },
    },
  },
  external_secret: secrets.ExternalSecret('ghost-jaredallard', namespace) {
    keys:: {
      database__client: { remoteRef: { key: 'GHOST_DATABASE_CLIENT' } },
      database__connection__database: { remoteRef: { key: 'MYSQL_DATABASE' } },
      database__connection__host: { remoteRef: { key: 'GHOST_DATABASE_HOST' } },
      database__connection__password: { remoteRef: { key: 'MYSQL_ROOT_PASSWORD' } },
      database__connection__port: { remoteRef: { key: 'GHOST_DATABASE_PORT' } },
      database__connection__user: { remoteRef: { key: 'GHOST_DATABASE_USER' } },
      mail__from: { remoteRef: { key: 'GHOST_MAIL_FROM' } },
      mail__transport: { remoteRef: { key: 'GHOST_MAIL_TRANSPORT' } },
      mail__options__service: { remoteRef: { key: 'GHOST_MAIL_OPTIONS_SERVICE' } },
      mail__options__auth__user: { remoteRef: { key: 'GHOST_MAIL_OPTIONS_AUTH_USER' } },
      mail__options__auth__pass: { remoteRef: { key: 'GHOST_MAIL_OPTIONS_AUTH_PASS' } },
    },
    secret_store:: $.doppler.secret_store,
    target:: 'ghost-jaredallard',
  },
  external_secret_mysql: secrets.ExternalSecret('ghost-mysql', namespace) {
    keys:: {
      MYSQL_DATABASE: { remoteRef: { key: 'MYSQL_DATABASE' } },
      MYSQL_ROOT_PASSWORD: { remoteRef: { key: 'MYSQL_ROOT_PASSWORD' } },
    },
    secret_store:: $.doppler.secret_store,
    target:: 'ghost-mysql',
  },
  doppler: secrets.DopplerSecretStore(name),

  mysql: argo.HelmApplication(
    chart='mysql',
    install_namespace=namespace,
    repoURL='https://groundhog2k.github.io/helm-charts',
    version='2.0.2',
    values={
      fullnameOverride: 'ghost-mysql',
      resources: {
        requests: {
          cpu: 1,
          memory: '1Gi',
        },
        limits: self.requests,
      },
      extraEnvSecrets: ['ghost-mysql'],
      storage: {
        requestedSize: '10Gi',
      },
    },
  ),
};

k.List() { items_:: all }
