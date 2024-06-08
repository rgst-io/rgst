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
local name = 'akkoma';
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
                repository: 'ghcr.io/jaredallard/akkoma',
                tag: 'v3.13.2',
              },
              command: ['sleep', 'infinity'],
              envFrom: [{ secretRef: { name: name } }],
            },
          },
          pod: {
            nodeSelector: {
              'kubernetes.io/hostname': 'ruka',
            },
          },
        },
      },
      defaultPodOptions: {
        securityContext: {
          runAsUser: 1000,
          runAsGroup: 1000,
          fsGroup: 1000,
          fsGroupChangePolicy: 'OnRootMismatch',
        },
      },
      service: {
        main: {
          controller: 'main',
          ports: {
            http: {
              port: 4000,
            },
          },
        },
      },
      ingress: {
        main: {
          enabled: true,
          annotations: {
            'cert-manager.io/cluster-issuer': 'main',
            'nginx.ingress.kubernetes.io/proxy-body-size': '100m',
          },
          className: 'nginx',
          hosts: [{
            host: 'satania.social',
            paths: [{
              path: '/',
              pathType: 'Prefix',
              service: {
                identifier: 'main',
              },
            }],
          }],
          tls: [{
            hosts: ['satania.social'],
            secretName: 'satania-social-tls',
          }],
        },
      },
      persistence: {
        config: {
          enabled: true,
          existingClaim: $.config_pv.metadata.name,
          globalMounts: [{
            path: '/opt/akkoma/config',
          }],
        },
        instance: {
          enabled: true,
          existingClaim: $.instance_pv.metadata.name,
          globalMounts: [{
            path: '/opt/akkoma/instance',
          }],
        },
      },
    },
  ),

  config_pv: k._Object('v1', 'PersistentVolume', '%s-config' % name, namespace) {
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
        path: '/volume1/kubernetes/static/akkoma/config',
        server: '100.69.242.81',  // yui.koi-insen.ts.net
      },
    },
  },
  config_pvc: k._Object('v1', 'PersistentVolumeClaim', '%s-config' % name, namespace) {
    spec: {
      accessModes: [
        'ReadWriteOnce',
      ],
      storageClassName: '',
      resources: {
        requests: {
          storage: $.config_pv.spec.capacity.storage,
        },
      },
      volumeName: $.config_pv.metadata.name,
    },
  },

  instance_pv: k._Object('v1', 'PersistentVolume', '%s-instance' % name, namespace) {
    spec: {
      storageClassName: '',
      capacity: {
        storage: '5Gi',
      },
      accessModes: [
        'ReadWriteOnce',
      ],
      persistentVolumeReclaimPolicy: 'Retain',
      mountOptions: [
        'nfsvers=4.1',
      ],
      nfs: {
        path: '/volume1/kubernetes/static/akkoma/instance',
        server: '100.69.242.81',  // yui.koi-insen.ts.net
      },
    },
  },
  instance_pvc: k._Object('v1', 'PersistentVolumeClaim', '%s-instance' % name, namespace) {
    spec: {
      accessModes: [
        'ReadWriteOnce',
      ],
      storageClassName: '',
      resources: {
        requests: {
          storage: $.instance_pv.spec.capacity.storage,
        },
      },
      volumeName: $.instance_pv.metadata.name,
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
