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

local argo = import '../../libs/argocd.libsonnet';
local secrets = import '../../libs/external-secrets.libsonnet';
local k = import '../../libs/k.libsonnet';

local name = 'cert-manager';

local all = {
  // https://artifacthub.io/packages/helm/cert-manager/cert-manager
  application: argo.HelmApplication(
    chart='cert-manager',
    repoURL='https://charts.jetstack.io',
    version='v1.17.1',
    values={
      installCRDs: true,
    },
  ) + {  // Everything depends on the CRDs existing so set this to sync-wave -1.
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-wave': '-1',
      },
    },
  },
};

k.List() { items_:: all }
