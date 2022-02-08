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

local argo = import '../libs/argocd.libsonnet';

argo.HelmApplication(
  chart='nfs-subdir-external-provisioner',
  repoURL='https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner',
  version='4.0.17',
  install_namespace='kube-system',
  values={
    nfs: {
      server: '100.69.242.81',
      mountOptions: ['nfsvers=4.1'],
      path: '/volume1/kubernetes/generated',
    },
    storageClass: {
      accessModes: 'ReadWriteMany',
      defaultClass: true,
    },
  },
)
