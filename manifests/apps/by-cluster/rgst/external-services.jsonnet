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
local secrets = import '../../../libs/external-secrets.libsonnet';
local k = import '../../../libs/k.libsonnet';

local namespace = 'external-services';

// external_service creates resources to allow access to a service
// running on Tailscale on a public URL. Generally speaking, authentik's
// auth proxy should be used instead of this.
// - name: The name of the service. Must be unique.
// - hostname: The hostname to use for the service. Must be unique.
// - address: The address of the service.
// - port: The port of the service.
local external_service(name, hostname, address, port) = k.Container {
  // Allow callers to access the name of the application.
  name:: name,

  ['%s_ingress' % name]: k._Object('networking.k8s.io/v1', 'Ingress', name=name, namespace=namespace) {
    metadata+: {
      annotations: {
        'cert-manager.io/cluster-issuer': 'main',
        // 200 Megabytes
        'nginx.ingress.kubernetes.io/proxy-body-size': '200m',
      },
    },
    spec: {
      ingressClassName: 'nginx',
      tls: [{
        hosts: [hostname],
        secretName: '%s-%s' % [name, std.strReplace(hostname, '.', '-')],
      }],
      rules: [{
        host: hostname,
        http: {
          paths: [{
            pathType: 'Prefix',
            path: '/',
            backend: {
              service: {
                name: name,
                port: {
                  name: 'http',
                },
              },
            },
          }],
        },
      }],
    },
  },
  ['%s_service' % name]: k._Object('v1', 'Service', name=name, namespace=namespace) {
    spec: {
      type: 'ClusterIP',
      selector: {},
      ports: [{
        name: 'http',
        port: port,
        protocol: 'TCP',
        targetPort: port,
      }],
    },
  },
  ['%s_endpoints' % name]: k._Object('v1', 'Endpoints', name=name, namespace=namespace) {
    subsets: [{
      addresses: [{ ip: address }],
      ports: [{
        name: 'http',
        port: port,
        protocol: 'TCP',
      }],
    }],
  },
};

// Create applications here using the app() function.
local external_services = [
  external_service(
    'skybridge',
    'skybridge.rgst.io',
    '100.89.247.22',  // portainer
    8080
  ),
  external_service(
    'kavita',
    'books.rgst.io',
    '100.69.242.81',  // yui
    5500,
  ),
];


local all = {
  [svc.name]: svc
  for svc in external_services
};

k.List() { items_:: all }
