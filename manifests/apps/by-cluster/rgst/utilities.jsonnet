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

local all = {
  // https://artifacthub.io/packages/helm/bjw-s/app-template
  helm_chart: argo.HelmApplication(
    app_name='plexanisync',
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
                repository: 'ghcr.io/rickdb/plexanisync',
                tag: '1.4.1',
              },
              env: [
                { name: 'PLEX_SECTION', value: 'Anime|Movies' },
                { name: 'ANI_USERNAME', value: 'itsdwari' },
                { name: 'INTERVAL', value: '3600' },
              ],
              envFrom: [{ secretRef: { name: 'plexanisync' } }],
            },
          },
        },
      },
    },
  ),
  external_secret: secrets.ExternalSecret('plexanisync', namespace) {
    keys:: {
      ANI_TOKEN: { remoteRef: { key: 'ANI_TOKEN' } },
      PLEX_TOKEN: { remoteRef: { key: 'PLEX_TOKEN' } },
      PLEX_URL: { remoteRef: { key: 'PLEX_URL' } },
    },
    secret_store:: $.doppler.secret_store,
    target:: 'plexanisync',
  },

  // Secret store used by all of the external secret objects.
  doppler: secrets.DopplerSecretStore(namespace),
};

k.List() { items_:: all }
