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

local name = 'maybe';
local namespace = name;

local all = {
  // https://artifacthub.io/packages/helm/bjw-s/app-template
  helm_chart: argo.HelmApplication(
    app_name=name,
    install_namespace=namespace,
    chart='app-template',
    repoURL='https://bjw-s.github.io/helm-charts/',
    version='3.5.1',
    values={
      controllers: {
        main: {
          containers: {
            main: {
              image: {
                repository: ' ghcr.io/maybe-finance/maybe',
                tag: '0.1.0-alpha.16',
              },
              env: {
                REQUIRE_INVITE_CODE: 'true',
                SELF_HOSTING_ENABLED: 'true',
                GOOD_JOB_EXECUTION_MODE: 'async',
              },
              envFrom: [{ secretRef: { name: name } }],
            },
          },
        },
      },
      service: {
        main: {
          controller: 'main',
          ports: {
            http: {
              port: 3000,
            },
          },
        },
      },
      persistence: {
        config: {
          enabled: true,
          existingClaim: $.pvc.metadata.name,
          globalMounts: [{
            path: '/rails/storage',
          }],
        },
      },
    },
  ),


  pvc: k._Object('v1', 'PersistentVolumeClaim', name, namespace) {
    spec: {
      accessModes: [
        'ReadWriteOnce',
      ],
      resources: {
        requests: {
          storage: '10Gi',
        },
      },
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
