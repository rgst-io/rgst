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

local argo = import '../../../../libs/argocd.libsonnet';
local secrets = import '../../../../libs/external-secrets.libsonnet';
local k = import '../../../../libs/k.libsonnet';

local name = 'ghost';

local all = {
  application: std.mergePatch(argo.HelmApplication(
    chart='ghost',
    repoURL='https://github.com/rgst-io/rgst',
    version='HEAD',
    values={
      fullnameOverride: 'ghost-jaredallard',
      settings: {
        url: 'https://blog.jaredallard.me',
      },

      ingress: {
        annotations: {
          'cert-manager.io/cluster-issuer': 'main',
          'kubernetes.io/ingress.class': 'nginx',
        },
        enabled: true,
        tls: [{
          hosts: ['blog.jaredallard.me'],
          secretName: 'ghost-jaredallard-tls',
        }],
        hosts: [{
          host: 'blog.jaredallard.me',
          paths: ['/'],
        }],
      },
      storage: {
        requestedSize: '80Gi',
        persistentVolumeClaimName: 'jaredallard-ghost',
      },

      // Database configuration
      mariadb: {
        enabled: false,
      },
      externalDatabase: {
        type: 'mysql',
        host: 'ghost-mysql',
        user: 'bn_ghost',
        name: 'ghost_jaredallard',
      },
    },
  ), {
    spec+: {
      source: {
        chart: null,
        // Forked until we get rid of secureconfig.yaml (secret in repos :()
        path: './charts/ghost',
      },
    },
  }),
  pvc: k._Object('v1', 'PersistentVolumeClaim', name, name) {
    metadata+: {
      name: 'jaredallard-ghost',
    },
    spec: {
      storageClassName: '',
      volumeName: 'jaredallard-ghost',
      accessModes: ['ReadWriteOnce'],
      resources: {
        requests: {
          storage: '80Gi',
        },
      },
    },
  },
  pv: k._Object('v1', 'PersistentVolume', name) {
    metadata+: {
      name: 'jaredallard-ghost',
    },
    spec: {
      capacity: {
        storage: '80Gi',
      },
      accessModes: ['ReadWriteOnce'],
      persistentVolumeReclaimPolicy: 'Retain',
      mountOptions: [
        'nfsvers=4.1',
      ],
      storageClassName: '',
      nfs: {
        path: '/volume1/kubernetes/static/jaredallard-ghost',
        server: '100.69.242.81',
      },
    },
  },
  external_secret: secrets.ExternalSecret('ghost-jaredallard', name) {
    keys:: {
      database__client: { remoteRef: { key: 'DATABASE_CLIENT' } },
      database__connection__database: { remoteRef: { key: 'MYSQL_DATABASE' } },
      database__connection__host: { remoteRef: { key: 'DATABASE_HOST' } },
      database__connection__password: { remoteRef: { key: 'MYSQL_PASSWORD' } },
      database__connection__port: { remoteRef: { key: 'DATABASE_PORT' } },
      database__connection__user: { remoteRef: { key: 'DATABASE_USER' } },
    },
    secret_store:: $.doppler.secret_store,
    target:: 'ghost-jaredallard',
  },
  external_secret_mysql: secrets.ExternalSecret('ghost-mysql', name) {
    keys:: {
      MYSQL_DATABASE: { remoteRef: { key: 'MYSQL_DATABASE' } },
      MYSQL_PASSWORD: { remoteRef: { key: 'MYSQL_PASSWORD' } },
      MYSQL_ROOT_PASSWORD: { remoteRef: { key: 'MYSQL_ROOT_PASSWORD' } },
      MYSQL_USER: { remoteRef: { key: 'MYSQL_USER' } },
    },
    secret_store:: $.doppler.secret_store,
    target:: 'ghost-mysql',
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
