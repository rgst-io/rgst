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

local name = 'loft';

local hostname = 'loft.rgst.io';

local all = {
  namespace: k._Object('v1', 'Namespace', name) {},
  // https://artifacthub.io/packages/helm/loft/loft
  application: argo.HelmApplication(
    chart='loft',
    repoURL='https://charts.loft.sh',
    version='3.4.9',
    values={
      admin: {
        create: false,
      },
      affinity: {
        nodeAffinity: {
          requiredDuringSchedulingIgnoredDuringExecution: {
            nodeSelectorTerms: [{
              matchExpressions: [{
                key: 'kubernetes.io/arch',
                operator: 'In',
                values: ['amd64'],
              }],
            }],
          },
        },
      },
      config: {
        loftHost: hostname,
        devPodSubDomain: '*-%s' % hostname,
      },
      ingress: {
        host: hostname,
        enabled: true,
        annotations: {
          'cert-manager.io/cluster-issuer': 'main',
        },
        tls: {
          enabled: true,
          secret: 'loft-tls',
        },
      },
      certIssuer: {
        create: false,
      },
    },
  ),
};

k.List() { items_:: all }
