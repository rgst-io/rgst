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
local secrets = import '../../../libs/external-secrets.libsonnet';
local k = import '../../../libs/k.libsonnet';
local name = 'immich';
local namespace = name;

local all = {
  // https://artifacthub.io/packages/helm/immich/immich
  helm_chart: argo.HelmApplication(
    chart=name,
    install_namespace=namespace,
    repoURL='https://immich-app.github.io/immich-charts',
    version='0.8.1',
    values={
      env: {  // Replaced by our secrets.
        DB_PASSWORD: null,
        DB_USERNAME: null,
        DB_HOSTNAME: null,
        DB_DATABASE_NAME: null,
      },
      envFrom: [{ secretRef: { name: name } }],

      immich: {
        persistence: {
          library: {
            existingClaim: $.pvc.metadata.name,
          },
        },
      },

      server: {
        ingress: {
          main: {
            enabled: true,
            annotations: {
              'cert-manager.io/cluster-issuer': 'main',
            },
            className: 'nginx',

            local host = 'immich.rgst.io',
            hosts: [{
              host: host,
              paths: [{
                path: '/',
                pathType: 'Prefix',
              }],
            }],
            tls: [{ hosts: [host], secretName: std.strReplace(host, '.', '-') + '-tls' }],
          },
        },
      },

      redis: {
        enabled: true,  // TODO(jaredallard): We should host one redis if possible.
      },
    },
  ),

  pv: k._Object('v1', 'PersistentVolume', name, namespace) {
    spec: {
      storageClassName: '',
      capacity: {
        storage: '2Ti',
      },
      accessModes: [
        'ReadWriteOnce',
      ],
      persistentVolumeReclaimPolicy: 'Retain',
      mountOptions: [
        'nfsvers=4.1',
      ],
      nfs: {
        path: '/volume1/pictures',
        server: '100.69.242.81',  // yui.koi-insen.ts.net
      },
    },
  },
  pvc: k._Object('v1', 'PersistentVolumeClaim', name, namespace) {
    spec: {
      accessModes: [
        'ReadWriteOnce',
      ],
      storageClassName: '',
      resources: {
        requests: {
          storage: $.pv.spec.capacity.storage,
        },
      },
      volumeName: $.pv.metadata.name,
    },
  },
  external_secret: secrets.ExternalSecret(name, name) {
    all_keys:: true,
    secret_store:: $.doppler.secret_store,
    target:: name,
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
