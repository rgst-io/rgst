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

local argo = import '../libs/argocd.libsonnet';

argo.JsonnetApplication(
  name='{{ .Cluster.Name }}',
  path='./manifests/apps/by-cluster/{{ .Cluster.Name }}',
  extVars={
    cluster_name: '{{ .Cluster.Name }}',
    config_domain: '{{ .Config.Domain }}',
    config_cluster_domain: '{{ .Config.ClusterDomain }}',
  },
  // No namespace because we let apps decide where to deploy
  install_namespace=null,
)
