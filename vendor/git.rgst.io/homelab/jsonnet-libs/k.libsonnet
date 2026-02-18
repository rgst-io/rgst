// Copyright (C) 2026 Jared Allard <jared@rgst.io>
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

// Lightly based off of https://github.com/bitnami-labs/kube-libsonnet/blob/master/kube.libsonnet
{
  local containerKey = '_|type|_',
  local containerValue = 'container',

  // getHiddenFieldValue returns a field only if it is hidden on an object
  getHiddenFieldValue(o, k):: if std.get(o, k, inc_hidden=true) == null then
    // We didn't find the field when including hidden fields, so return null.
    null
  else
    // We found the key when we included hidden fields, so now check if it is
    // also returned when we don't include hidden fields.
    if std.get(o, k, default=null, inc_hidden=false) != null then
      // The key was also returned when we didn't include hidden fields (not hidden), so return null.
      null
    else
      // The key was not returned when we didn't include hidden fields, so return the value.
      std.get(o, k, inc_hidden=true),

  // flattenMixedArrays flattens items in an array that are not the same type (e.g. objects + arrays)
  // which std.flattenArrays() does not work on.
  flattenMixedArrays(arrs):: std.foldl(function(a, b) if std.isArray(b) then a + b else a + [b], arrs, []),

  // Returns an array of each distinct key in the given object. If a object is a container
  // it will return the keys of the container as well. See "Container".
  objectValues(o):: $.flattenMixedArrays([
    // If we're an object, check if we have the container key
    if std.isObject(v) then
      // If we have the container key, run objectValues again on the object
      // so that we include those as top level objects in the list.
      if $.getHiddenFieldValue(v, containerKey) == containerValue then
        $.objectValues(v)
      else v
    else v
    for v in [o[k] for k in std.objectFields(o)]
  ]),

  // Returns true if a value is not equal to null
  isNotNull(v):: v != null,

  hyphenate(s):: std.join('-', std.split(s, '_')),

  // mapToNamedList takes a map of objects and returns a list of objects with
  // the key as the name field.
  mapToNamedList(o, nameKey='name'):: [{ [nameKey]: n } + o[n] for n in std.objectFields(o)],

  // envList takes a map of environment variables and returns a list of
  // objects with the key as the name field and the value as the value
  // field.
  envList(map):: [
    if std.type(map[x]) == 'object' then { name: x, valueFrom: map[x] } else { name: x, value: map[x] }
    for x in std.objectFields(map)
  ],

  // List returns a list of Kubernetes Objects. Filters out null entries.
  List():: $._Object('v1', 'List') {
    items_:: {},
    // Filter out null objects
    items: std.filter($.isNotNull, $.objectValues(self.items_)),
  },

  // Container is a container of objects. This is useful for creating sub-objects and
  // having them also be included into a list created from an object (e.g. List()). This
  // works anywhere objectValues() is used.
  Container:: {
    [containerKey]:: containerValue,
    assert self[containerKey] == containerValue : 'Container "%s" field was mutated' % containerKey,
  },

  // Object creates a Kubernetes Object
  _Object(apiVersion, kind, name=null, namespace=null):: {
    apiVersion: apiVersion,
    kind: kind,
    // Only include metadata if name or namespace is set.
    [if name != null || namespace != null then 'metadata']: {
      [if name != null then 'name']: name,
      [if namespace != null then 'namespace']: namespace,
    },
  },

  // ConfigMap creates a configmap with string guarantees if the data_
  // subfield is used.
  ConfigMap(name, namespace):: $._Object('v1', 'ConfigMap', name, namespace) {
    local this = self,
    data_:: {},
    data: {
      // ConfigMap keys must be strings.
      [key]: std.toString(this.data_[key])
      for key in std.objectFields(this.data_)
    },
  },
}
