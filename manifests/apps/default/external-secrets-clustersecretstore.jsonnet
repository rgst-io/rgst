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

local argo = import '../../libs/argocd.libsonnet';
local secrets = import '../../libs/external-secrets.libsonnet';
local k = import '../../libs/k.libsonnet';

local name = 'external-secrets-clustersecretstore';

local all = {
  // https://artifacthub.io/packages/helm/cert-manager/cert-manager
  application: argo.JsonnetApplication(name, install_namespace='external-secrets'),
};

k.List() { items_:: all }
