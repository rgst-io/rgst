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

local name = 'tailscale-operator';

local all = {
  namespace: k._Object('v1', 'Namespace', name) {},
  helm_chart: argo.HelmApplication(
    chart=name,
    repoURL='https://pkgs.tailscale.com/helmcharts',
    version='1.78.3',
    install_namespace=name,
    values={}
  ),
  external_secret: secrets.ExternalSecret(name, name) {
    keys:: {
      client_id: { remoteRef: { key: 'CLIENT_ID' } },
      client_secret: { remoteRef: { key: 'CLIENT_SECRET' } },
    },
    secret_store:: $.doppler.secret_store,
    target:: 'operator-oauth',
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
