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

local name = 'rmfakecloud';
local namespace = name;

local all = {
  namespace: k._Object('v1', 'Namespace', name) {},
  // https://artifacthub.io/packages/helm/bjw-s/app-template
  helm_chart: argo.HelmApplication(
    app_name=name,
    install_namespace=namespace,
    chart='app-template',
    repoURL='https://bjw-s.github.io/helm-charts/',
    version='3.6.1',
    values={
      controllers: {
        main: {
          containers: {
            main: {
              image: {
                repository: 'ddvk/rmfakecloud',
                tag: '0.0.23',
              },
              env: {
                STORAGE_URL: 'https://rmfakecloud.koi-insen.ts.net',
              },
              envFrom: [{ secretRef: { name: name } }],
            },
          },
        },
      },
      service: {
        main: {
          controller: 'main',
          ports: { http: { port: 3000 } },
        },
      },
      ingress: {
        main: {
          enabled: true,
          className: 'tailscale',
          defaultBackend: {
            service: {
              name: name,
              port: {
                name: 'http',
              },
            },
          },
          tls: [{
            hosts: ['rmfakecloud'],
          }],
        },
      },
      persistence: {
        config: {
          enabled: true,
          existingClaim: $.pv.metadata.name,
          globalMounts: [{
            path: '/data',
          }],
        },
      },
    },
  ),

  pv: k._Object('v1', 'PersistentVolume', name, namespace) {
    spec: {
      storageClassName: '',
      capacity: {
        storage: '1Gi',
      },
      accessModes: [
        'ReadWriteOnce',
      ],
      persistentVolumeReclaimPolicy: 'Retain',
      mountOptions: [
        'vers=3',
        'local_lock=posix'
      ],
      nfs: {
        path: '/volume1/kubernetes/static/rmfakecloud',
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
