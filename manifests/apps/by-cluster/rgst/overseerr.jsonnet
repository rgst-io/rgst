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
local k = import '../../../libs/k.libsonnet';
local name = 'overseerr';
local namespace = name;

local all = {
  // https://artifacthub.io/packages/helm/bjw-s/app-template
  helm_chart: argo.HelmApplication(
    app_name=name,
    install_namespace=namespace,
    chart='app-template',
    repoURL='https://bjw-s.github.io/helm-charts/',
    version='3.2.1',
    values={
      controllers: {
        main: {
          containers: {
            main: {
              image: {
                repository: 'ghcr.io/sct/overseerr',
                tag: '1.33.2',
              },
              env: {
                TZ: 'America/Los_Angeles',
              },
            },
          },
          pod: {
            nodeSelector: {
              'kubernetes.io/hostname': 'shino',
            },
          },
        },
      },
      service: {
        main: {
          controller: 'main',
          ports: {
            http: {
              port: 5055,
            },
          },
        },
      },
      ingress: {
        main: {
          enabled: true,
          annotations: {
            'cert-manager.io/cluster-issuer': 'main',
          },
          className: 'nginx',
          hosts: [{
            host: 'media.rgst.io',
            paths: [{
              path: '/',
              pathType: 'Prefix',
              service: {
                identifier: 'main',
              },
            }],
          }],
          tls: [{
            hosts: ['media.rgst.io'],
            secretName: 'media-rgst-io-tls',
          }],
        },
      },
      persistence: {
        config: {
          enabled: true,
          existingClaim: $.pv.metadata.name,
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
        'nfsvers=4.1',
      ],
      nfs: {
        path: '/volume1/kubernetes/static/overseerr',
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
};

k.List() { items_:: all }
