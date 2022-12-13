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

argo.HelmApplication(
  chart='owncast',
  repoURL='https://k8s-at-home.com/charts',
  version='3.4.2',
  release_name='gcp',
  values={
    iamge: {
      tag: '0.0.13',
    },
    env: {
      TZ: 'America/Los_Angeles',
    },
    ingress: {
      main: {
        enabled: true,
        ingressClassName: 'nginx',
        tls: [{
          hosts: ['video.rgst.io'],
          secretName: 'video-rgst-io-tls',
        }],
      },
    },
  }
)
