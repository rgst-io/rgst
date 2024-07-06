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

local k = import '../../../libs/k.libsonnet';

local all = {
  namespace: k._Object('v1', 'Namespace', 'portainer') {
    metadata+: {
      name: 'portainer',
    },
  },
  cronjob: k._Object('batch/v1', 'CronJob', 'update-portainer-stack') {
    metadata+: {
      name: 'update-portainer-stack',
      namespace: 'portainer',
    },
    spec: {
      // https://crontab.guru/every-week
      schedule: '0 0 * * 0',
      jobTemplate: {
        spec: {
          template: {
            spec: {
              containers: [{
                name: 'default',
                image: 'alpine/httpie:3.2.2',
                command: ['ash', '-e', '-c'],
                args: ['exec http POST "$PORTAINER_HOST/api/stacks/webhooks/$WEBHOOK_ID"'],
                env: k.envList({
                  PORTAINER_HOST: 'https://portainer.rgst.io',
                  WEBHOOK_ID: 'afd2f2ff-7b7d-4bf8-92af-d5ab2ecc36bc',
                }),
              }],
              restartPolicy: 'OnFailure',
            },
          },
        },
      },
    },
  },
};

k.List() { items_:: all }
