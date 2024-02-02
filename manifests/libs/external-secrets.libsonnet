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

local k = import './k.libsonnet';

{
  // SecretStoreRef is a reference to a secret store.
  SecretStoreRef(secStore):: {
    kind: secStore.kind,
    name: secStore.metadata.name,
  },

  ExternalSecret(name, namespace):: k._Object('external-secrets.io/v1beta1', 'ExternalSecret', name, namespace) {
    keys:: {},
    all_keys:: false,
    assert std.length(self.keys) > 0 || self.all_keys : 'Either keys or all_keys must be set',

    secret_store:: {},
    assert self.secret_store != null : 'secret_store must be set',

    target:: '',
    assert self.target != '' : 'target must be set',

    local this = self,
    spec: {
      secretStoreRef: $.SecretStoreRef(this.secret_store),
      [if std.length(this.keys) > 0 then 'data']: k.mapToNamedList(this.keys, 'secretKey'),
      [if this.all_keys then 'dataFrom']: [{ find: { name: { regexp: '.*' } } }],
      target: { name: this.target },
    },
  },

  SecretStore(name, namespace):: k._Object('external-secrets.io/v1beta1', 'SecretStore', name, namespace) {
    local this = self,
    doppler_:: {
      secret: {
        name: '',
        namespace: '',
        key: '',
      },
    },

    spec: {
      provider: {
        [if this.doppler_.secret.name != '' then 'doppler']: {
          auth: {
            secretRef: {
              dopplerToken: {
                name: this.doppler_.secret.name,
                [if std.objectHas(this.doppler_.secret, 'namespace') then 'namespace']: this.doppler_.secret.namespace,
                key: this.doppler_.secret.key,
              },
            },
          },
        },
      },
    },
  },
  ClusterSecretStore(name):: $.SecretStore(name, '') {
    kind: 'ClusterSecretStore',
    metadata: std.mergePatch(super.metadata, {
      namespace: null,
    }),
  },

  DopplerSecretStore(name, project=name, namespace=name):: k.Container {
    secret_store: $.SecretStore(name, namespace) {
      doppler_:: {
        secret: {
          name: 'doppler',
          key: 'token',
        },
      },
    },
    external_secret: $.ExternalSecret('doppler', namespace) {
      secret_store:: $.ClusterSecretStore('kubernetes'),
      keys:: {
        token: {
          remoteRef: {
            key: 'DOPPLER_TOKEN_%s' % std.asciiUpper(std.join('_', std.split(project, '-'))),
          },
        },
      },
      target:: 'doppler',
    },
  },
}
