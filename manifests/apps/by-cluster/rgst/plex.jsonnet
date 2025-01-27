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

local name = 'plex';
local namespace = 'media-center';
local node = 'mocha';

local all = {
  namespace: k._Object('v1', 'Namespace', namespace),
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
                repository: 'linuxserver/plex',
                tag: 'latest',
              },
              securityContext: {
                supplementalGroups: [self.fsGroup],
                fsGroup: 65537,
              },
              env: {
                TZ: 'America/Los_Angeles',
                PUID: 1031,
                PGID: 65537,
                VERSION: 'docker',
                NVIDIA_VISIBLE_DEVICES: 'all',
                NVIDIA_DRIVER_CAPABILITIES: 'all',
              },
              ports: [
                {
                  containerPort: 32400,
                  name: 'plex-https',
                  hostPort: 32400,
                  protocol: 'TCP',
                },
                {
                  containerPort: 32400,
                  name: 'plex-http-udp',
                  hostPort: 32400,
                  protocol: 'UDP',
                },
                {
                  containerPort: 32469,
                  hostPort: 32469,
                  protocol: 'TCP',
                },
                {
                  containerPort: 32469,
                  protocol: 'UDP',
                  hostPort: 32469,
                },
                {
                  containerPort: 5353,
                  hostPort: 5353,
                  protocol: 'UDP',
                },
                {
                  containerPort: 1900,
                  hostPort: 1900,
                  protocol: 'UDP',
                },
              ],
            },
          },
          // initContainers: {
          //   chown: {
          //     image: {
          //       repository: 'alpine',
          //       tag: 'latest',
          //     },
          //     securityContext: {
          //       runAsUser: 0,
          //     },
          //     command: [
          //       'sh',
          //       '-euc',
          //       'chmod 0775 /data/*; chown -R 1031:65537 /data; chmod 0775 /config; chown -R 1031:65537 /config',
          //     ],
          //   },
          // },
          pod: {
            nodeSelector: {
              'kubernetes.io/hostname': node,
            },
            //runtimeClassName: 'nvidia',
          },
        },
      },
      persistence: {
        media: {
          enabled: true,
          existingClaim: $.media_pv.metadata.name,
          globalMounts: [{
            path: '/data/media',
          }],
        },
        config: {
          enabled: true,
          existingClaim: $.plex_config_pvc.metadata.name,
          globalMounts: [{
            path: '/config',
          }],
        },
        transcoding: {
          enabled: true,
          type: 'emptyDir',
          globalMounts: [{
            path: '/transcoding',
          }],
        },
      },
    }
  ),
  runtime_class: k._Object('node.k8s.io/v1', 'RuntimeClass', 'nvidia') {
    handler: 'nvidia',
  },


  plex_config_pvc: k._Object('v1', 'PersistentVolumeClaim', 'plex-config', namespace) {
    spec: {
      storageClassName: '',
      accessModes: [
        'ReadWriteOnce',
      ],
      resources: {
        requests: { storage: $.plex_config_pv.spec.capacity.storage },
      },
      volumeName: $.plex_config_pv.metadata.name,
    },
  },
  plex_config_pv: k._Object('v1', 'PersistentVolume', 'plex-config') {
    spec: {
      storageClassName: '',
      capacity: {
        storage: '150Gi',
      },
      accessModes: [
        'ReadWriteOnce',
      ],
      persistentVolumeReclaimPolicy: 'Retain',
      mountOptions: [
        'nfsvers=4.1',
      ],
      nfs: {
        path: '/volume1/kubernetes/static/plex',
        server: '100.69.242.81',  // yui.koi-insen.ts.net
      },
    },
  },
  media_pvc: k._Object('v1', 'PersistentVolumeClaim', 'media-storage', namespace) {
    spec: {
      accessModes: [
        'ReadWriteOnce',
      ],
      storageClassName: '',
      resources: {
        requests: { storage: $.media_pv.spec.capacity.storage },
      },
      volumeName: $.media_pv.metadata.name,
    },
  },
  media_pv: k._Object('v1', 'PersistentVolume', 'media-storage') {
    spec: {
      storageClassName: '',
      capacity: {
        storage: '3Ti',
      },
      accessModes: [
        'ReadWriteOnce',
      ],
      persistentVolumeReclaimPolicy: 'Retain',
      mountOptions: [
        'nfsvers=4.1',
      ],
      nfs: {
        path: '/volume1/media',
        server: '100.69.242.81',  // yui.koi-insen.ts.net
      },
    },
  },
};

k.List() { items_:: all }
