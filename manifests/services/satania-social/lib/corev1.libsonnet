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

local k = import 'k.libsonnet';

local filterNull(list) = std.filter(function(v) v != null, list);
local m(list) = std.foldl(function(a, b) a + b, std.filter(function(v) v != null, list), {});


local corev1 = k.core.v1 {
  container+: {
    // new is the same as k.core.v1.container.new with an 'opts'
    // argument that takes the value of with functions and merges them
    // into the container object
    new(name, image, opts=[]):: k.core.v1.container.new(name, image) + m(opts),
    readinessProbe+: {
      // new creates a new readinessProbe with options
      new(opts=[]):: m(opts),
      httpGet+: {
        // new creates a new httpGet probe with options
        new(path='', port=-1, opts=[]):: {
          readinessProbe+: {
            httpGet: {},
          },
        } + m(filterNull([
          if path != '' then self.withPath(path) else null,
          if port != -1 then self.withPort(port) else null,
        ]) + opts),
      },
    },
    livenessProbe+: {
      // new creates a new livenessProbe with options
      new(opts=[]):: m(opts),
      httpGet+: {
        // new creates a new httpGet livenessProbe with
        // options
        new(path='', port=-1, opts=[]):: {
          livenessProbe+: {
            httpGet+: {},
          },
        } + m(filterNull([
          if path != '' then self.withPath(path) else null,
          if port != -1 then self.withPort(port) else null,
        ]) + opts),
      },
    },
  },
};

corev1
