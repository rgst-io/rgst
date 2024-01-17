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

local k = import './k.libsonnet';

{
  Application(name, install_namespace=name, project='default'):: k._Object('argoproj.io/v1alpha1', 'Application', name, 'argocd') {
    // For ease of accesing elsewhere
    namespace:: install_namespace,
    spec: {
      project: project,
      destination: {
        [if install_namespace != null then 'namespace']: install_namespace,
        server: 'https://kubernetes.default.svc',
      },
      syncPolicy: {
        syncOptions: [
          'CreateNamespace=true',
        ],
        automated: {
          prune: true,
          selfHeal: true,
        },
      },
    },
  },

  HelmApplication(chart, repoURL, version, values={}, install_namespace=chart, release_name=null, app_name=null):: $.Application(name=if app_name == null then chart else app_name, install_namespace=install_namespace) {
    spec+: {
      source+: {
        chart: chart,
        repoURL: repoURL,
        targetRevision: version,
        helm: {
          [if release_name != null then 'releaseName']: release_name,
          values: std.manifestYamlDoc(values, true),
        },
      },
    },
  },

  JsonnetApplication(name, path=('./manifests/services/' + name), install_namespace=name, extVars=null):: $.Application(name=name, install_namespace=install_namespace) {
    spec+: {
      source+: {
        directory: {
          jsonnet: {
            [if extVars != null then 'extVars']: [{ name: k, value: extVars[k] } for k in std.objectFields(extVars)],
          },
          recurse: true,
        },
        path: path,
        repoURL: 'https://github.com/rgst-io/rgst',
        targetRevision: 'HEAD',
      },
    },
  },
}
