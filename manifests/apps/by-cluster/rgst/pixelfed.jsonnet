// Copyright (C) 2025 Jared Allard <jared@rgst.io>
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

local argo = import '../../../../vendor/jsonnet-libs/argocd.libsonnet';
local secrets = import '../../../../vendor/jsonnet-libs/external-secrets.libsonnet';
local k = import '../../../../vendor/jsonnet-libs/k.libsonnet';

local name = 'pixelfed';
local namespace = name;
local host = 'lens.im';

local all = {
  local setup_steps = [
    // Ensure we don't have a .env, because we read only from environment variables.
    'rm -f /var/www/.env',
    'touch /var/www/.env',

    // Recreate www-data to match our actual conditions
    'userdel www-data',
    'groupadd -g $RUNTIME_GID www-data',
    'useradd -u $RUNTIME_UID -g $RUNTIME_GID www-data',
    'chown -R $RUNTIME_UID:$RUNTIME_GID /var/www',
  ],

  namespace: k._Object('v1', 'Namespace', namespace),
  // https://artifacthub.io/packages/helm/bjw-s/app-template
  helm_chart: argo.HelmApplication(
    app_name=name,
    install_namespace=namespace,
    chart='app-template',
    repoURL='https://bjw-s.github.io/helm-charts/',
    version='3.7.3',
    values={
      controllers: {
        main: {
          strategy: 'RollingUpdate',
          rollingUpdate: {
            unavailable: '0',
          },
          containers: {
            main: {
              image: {
                repository: 'ghcr.io/jaredallard/pixelfed',
                // https://github.com/jaredallard/pixelfed/tree/release-0.12.5
                tag: 'v0.12.5-jaredallard.2',
              },
              command: [
                'bash',
                '-exc',
                std.join(' && ', setup_steps + [
                  'exec /docker/entrypoint.sh forego start -r',
                ]),
              ],
              env: {
                RUNTIME_UID: 1031,
                RUNTIME_GID: 65537,
              },
              envFrom: [
                { secretRef: { name: name } },
                { configMapRef: { name: name } },
              ],
              probes: {
                readiness: {
                  enabled: true,
                  type: 'HTTP',
                  path: '/api/service/health-check',
                  port: 80,
                  spec+: {
                    httpHeaders: [{
                      name: 'Host',
                      value: host,
                    }],
                  },
                },
              },
            },
          },
          pod: {
            nodeSelector: {
              'kubernetes.io/hostname': 'ruka',
            },
          },
        },
        worker: self.main {
          containers+: {
            main+: {
              command: [
                'bash',
                '-exc',
                std.join(' && ', setup_steps + [
                  'exec gosu www-data php artisan horizon',
                ]),
              ],
              probes: {
                readiness: {
                  enabled: true,
                  custom: true,
                  spec+: {
                    exec: {
                      command: ['/bin/bash', '-euc', 'gosu www-data php artisan horizon:status | grep -q running'],
                    },
                    periodSeconds: 5,
                    failureThreshold: 3,
                  },
                },
              },
            },
          },
        },
        tasks: self.main {
          type: 'cronjob',
          cronjob: {
            // Every 5 minutes
            schedule: '*/5 * * * *',
          },
          containers+: {
            main+: {
              command: [
                'bash',
                '-exc',
                std.join(' && ', setup_steps + [
                  'exec gosu www-data php artisan schedule:run',
                ]),
              ],
              probes: {},  // No probes needed.
            },
          },
        },
      },
      defaultPodOptions: {
        securityContext: {
          fsGroup: 65537,
          supplementalGroups: [self.fsGroup],
          fsGroupChangePolicy: 'Always',
        },
      },
      service: {
        main: {
          controller: 'main',
          ports: {
            http: {
              port: 80,
            },
          },
        },
      },
      ingress: {
        main: {
          enabled: true,
          annotations: {
            'cert-manager.io/cluster-issuer': 'main',
            'nginx.ingress.kubernetes.io/proxy-body-size': '100m',
          },
          className: 'nginx',
          hosts: [{
            host: host,
            paths: [{
              path: '/',
              pathType: 'Prefix',
              service: {
                identifier: 'main',
              },
            }],
          }],
          tls: [{
            hosts: [host],
            secretName: std.strReplace(host, '.', '-') + '-tls',
          }],
        },
      },
      persistence: {
        instance: {
          enabled: true,
          existingClaim: $.instance_pv.metadata.name,
          globalMounts: [{
            path: '/var/www/storage',
          }],
        },
      },
    },
  ),

  configmap: k.ConfigMap(name, namespace) {
    data_:: {
      APP_NAME: 'Lens.im',
      APP_URL: 'https://%s' % host,
      APP_DOMAIN: host,
      ADMIN_DOMAIN: self.APP_DOMAIN,
      SESSION_DOMAIN: self.ADMIN_DOMAIN,

      // Config
      APP_LOCALE: 'en',
      INSTANCE_DESCRIPTION: 'Share your life with others :)',
      INSTANCE_CONTACT_FORM: true,
      INSTANCE_CONTACT_EMAIL: 'lens-im@rgst.io',
      APP_TIMEZONE: 'America/Los_Angeles',  // West coast best coast :D
      DB_CONNECTION: 'mysql',
      DB_USERNAME: 'pixelfed',
      DB_DATABASE: 'pixelfed',
      DB_HOST: '100.109.240.128',  // ruka.koi-insen.ts.net
      DB_PORT: 3306,
      DOCKER_DB_HOST_PORT: self.DB_PORT,
      REDIS_HOST: 'redis.%s.svc.cluster.local' % namespace,
      REDIS_PASSWORD: '',
      QUEUE_DRIVER: 'redis',

      // Features
      INSTANCE_DISCOVER_PUBLIC: true,
      INSTANCE_PUBLIC_HASHTAGS: true,
      INSTANCE_PUBLIC_LOCAL_TIMELINE: true,
      STORIES_ENABLED: true,
      ACTIVITY_PUB: true,
      AP_REMOTE_FOLLOW: true,
      AP_SHAREDINBOX: true,
      IMPORT_INSTAGRAM: true,
      IMPORT_INSTAGRAM_POST_LIMIT: 1000,
      IMPORT_INSTAGRAM_SIZE_LIMIT: 20000,
      PF_IMPORT_IG_PERM_MIN_ACCOUNT_AGE: 0,
      IMAGE_DRIVER: 'imagick',
      MEDIA_TYPES: 'image/jpeg,image/png,image/gif,image/webp,image/avif,image/heic,video/mov,video/mp4',

      // User limits
      OPEN_REGISTRATION: false,  // For now.
      LIMIT_ACCOUNT_SIZE: false,
      MAX_CAPTION_LENGTH: 5000,
      MAX_BIO_LENGTH: 150,
      MAX_NAME_LENGTH: 30,

      // Image settings
      PF_HIDE_NSFW_ON_PUBLIC_FEEDS: true,
      PF_LOCAL_AVATAR_TO_CLOUD: true,
      IMAGE_QUALITY: 95,
      PF_OPTIMIZE_IMAGES: false,
      PF_OPTIMIZE_VIDEOS: true,
      MAX_ALBUM_LENGTH: 20,

      // Object Storage
      PF_ENABLE_CLOUD: true,
      FILESYSTEM_CLOUD: 's3',
      AWS_USE_PATH_STYLE_ENDPOINT: true,
      AWS_BUCKET: 'obj-lens-im',
      AWS_REGION: 'auto',
      AWS_ENDPOINT: 'https://c41358b3e2e8f5345933f0d433e3abef.r2.cloudflarestorage.com',
      AWS_URL: 'https://obj.lens.im',

      // Mail
      MAIL_DRIVER: 'smtp',
      MAIL_HOST: 'smtp.mailgun.org',
      MAIL_PORT: 465,
      MAIL_USERNAME: 'lens@rgst.io',
      MAIL_FROM_ADDRESS: 'noreply@rgst.io',
      MAIL_FROM_NAME: 'lens.im',
      MAIL_ENCRYPTION: 'tls',

      // Docker-specific settings
      DOCKER_APP_RUN_ONE_TIME_SETUP_TASKS: 0,
      DOCKER_APP_PHP_MEMORY_LIMIT: '512M',
    },
  },

  instance_pv: k._Object('v1', 'PersistentVolume', name, namespace) {
    spec: {
      storageClassName: '',
      capacity: {
        storage: '5Gi',
      },
      accessModes: [
        'ReadWriteOnce',
      ],
      persistentVolumeReclaimPolicy: 'Retain',
      mountOptions: [
        'nfsvers=4.1',
      ],
      nfs: {
        path: '/volume1/kubernetes/static/%s' % name,
        server: '100.69.242.81',  // yui.koi-insen.ts.net
      },
    },
  },
  instance_pvc: k._Object('v1', 'PersistentVolumeClaim', name, namespace) {
    spec: {
      accessModes: [
        'ReadWriteOnce',
      ],
      storageClassName: '',
      resources: {
        requests: {
          storage: $.instance_pv.spec.capacity.storage,
        },
      },
      volumeName: $.instance_pv.metadata.name,
    },
  },

  redis: argo.HelmApplication(
    app_name='redis',
    install_namespace=namespace,
    chart='redis',
    repoURL='https://groundhog2k.github.io/helm-charts',
    version='2.0.2',
    values={
      image: {
        repository: 'redis',
        tag: '8.0.2',
      },
    }
  ),

  external_secret: secrets.ExternalSecret(name, namespace) {
    all_keys:: true,
    secret_store:: $.doppler.secret_store,
    target:: name,
  },
  doppler: secrets.DopplerSecretStore(name),
};

k.List() { items_:: all }
