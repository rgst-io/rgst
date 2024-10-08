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

local all = {
  // https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
  application: argo.HelmApplication(
    chart='ingress-nginx',
    repoURL='https://kubernetes.github.io/ingress-nginx',
    version='4.11.2',
    values={
      controller: {
        allowSnippetAnnotations: true,
        dnsPolicy: 'ClusterFirstWithHostNet',
        service: {
          type: 'ClusterIP',
        },
        hostPort: {
          enabled: true,
        },
        replicaCount: 1,
        nodeSelector: {
          'kubernetes.io/hostname': 'ruka',
        },
        updateStrategy: {
          type: 'Recreate',
        },

        config: {
          // curl https://www.cloudflare.com/ips-v4/ | sed 's/^/"/' | sed 's/$/",/' | pbcopy
          // curl https://www.cloudflare.com/ips-v6/ | sed 's/^/"/' | sed 's/$/",/' | pbcopy
          //
          // Last Updated: Oct 7, 2024
          'proxy-real-ip-cidr': std.join(',', [
            '173.245.48.0/20',
            '103.21.244.0/22',
            '103.22.200.0/22',
            '103.31.4.0/22',
            '141.101.64.0/18',
            '108.162.192.0/18',
            '190.93.240.0/20',
            '188.114.96.0/20',
            '197.234.240.0/22',
            '198.41.128.0/17',
            '162.158.0.0/15',
            '104.16.0.0/13',
            '104.24.0.0/14',
            '172.64.0.0/13',
            '131.0.72.0/22',
            '2400:cb00::/32',
            '2606:4700::/32',
            '2803:f800::/32',
            '2405:b500::/32',
            '2405:8100::/32',
            '2a06:98c0::/29',
            '2c0f:f248::/32',
          ]),
          // This is the important part
          'use-forwarded-headers': 'true',
          // Still works without this line because it defaults to X-Forwarded-For, but I use it anyways
          'forwarded-for-header': 'CF-Connecting-IP',
        },
      },
    }
  ),
};

k.List() { items_:: all }
