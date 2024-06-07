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

local namespace = 'utilities';

local doppler = secrets.DopplerSecretStore(namespace);

// app creates an application. Values are:
// - name: the name of the application, used as the name of all
//   associated resources.
// - container: a container object, as defined in the app-template helm
//   chart.
// - app_secrets: a list of secret keys to be fetched from the secret
//   store, should match the keys in the secret store and expected
//   env var name.
local app(name, container, app_secrets) = k.Container {
  // Allow callers to access the name of the application.
  name:: name,

  ['%s_helm_chart' % name]: argo.HelmApplication(
    app_name=name,
    install_namespace=namespace,
    chart='app-template',
    repoURL='https://bjw-s.github.io/helm-charts/',
    version='3.2.1',
    values={
      controllers: {
        main: {
          containers: {
            main: container {
              envFrom: [{ secretRef: { name: name } }],
            },
          },
        },
      },
    },
  ),
  ['%s_external_secret' % name]: secrets.ExternalSecret(name, namespace) {
    keys:: {
      [key]: {
        remoteRef: {
          key: key,
        },
      }
      for key in app_secrets
    },
    secret_store:: doppler.secret_store,
    target:: name,
  },
};

// Create applications here using the app() function.
local apps = [
  app(
    'plexanisync',
    {
      image: {
        repository: 'ghcr.io/rickdb/plexanisync',
        tag: '1.4.1',
      },
      env: k.envList({
        PLEX_SECTION: 'Anime|Movies',
        ANI_USERNAME: 'itsdwari',
        INTERVAL: '3600',
      }),
    },
    ['PLEX_TOKEN', 'PLEX_URL', 'ANI_TOKEN'],
  ),
];


local all = {
  // Create an application key for each app in the apps list.
  [app.name]: app
  for app in apps
} + {
  // Secret store used by all of the external secret objects.
  doppler: doppler,
};

k.List() { items_:: all }
