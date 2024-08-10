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

argo.HelmApplication(
  chart='kube-cleanup-operator',
  repoURL='https://charts.lwolf.org',
  version='1.0.4',
  values={
    image: {
      repository: 'quay.io/lwolf/kube-cleanup-operator',
      tag: '0.8.4',
    },
    rbac: {
      create: true,
      global: true,
    },
    args: [
      '--delete-failed-after=60m',
      '--delete-successful-after=60m',
      '--delete-pending-pods-after=60m',
      '--delete-evicted-pods-after=60m',
      '--delete-orphaned-pods-after=60m',
      '--legacy-mode=false',
    ],
  }
)
