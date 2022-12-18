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

local name = 'jsonnet-dev';

local all = {
  application: std.mergePatch(argo.HelmApplication(
    chart=name,
    repoURL='https://github.com/rgst-io/rgst',
    version='HEAD',
    values={
      replicaCount: 3,
    },
  ), {
    spec+: {
      source: {
        chart: null,
        path: './charts/jsonnet-dev',
      },
    },
  }),
  external_secret: secrets.ExternalSecret(name, name) {
    all_keys:: true,
    secret_store:: $.doppler.secret_store,
    target:: '%s-postgres' % name,
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
