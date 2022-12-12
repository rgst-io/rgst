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

local config = {
  // This is a sample configuration file. You can generate your configuration
  // with the `rake mastodon:setup` interactive setup wizard, but to customize
  // your setup even further, you'll need to edit it manually. This sample does
  // not demonstrate all available configuration options. Please look at
  // https://docs.joinmastodon.org/admin/config/ for the full documentation.

  // Note that this file accepts slightly different syntax depending on whether
  // you are using `docker-compose` or not. In particular, if you use
  // `docker-compose`, the value of each declared variable will be taken verbatim,
  // including surrounding quotes.
  // See: https://github.com/mastodon/mastodon/issues/16895

  // Federation
  // ----------
  // This identifies your server and cannot be changed safely later
  // ----------
  LOCAL_DOMAIN: 'mstdn.satania.social',
  STREAMING_API_BASE_URL: '',
  RAILS_SERVE_STATIC_FILES: true,

  // Redis
  // -----
  REDIS_URL: 'redis://10.11.0.3:6379',

  // PostgreSQL
  // ----------
  DB_HOST: '10.9.0.5',
  DB_USER: 'postgres',
  DB_NAME: 'mastodon',
  DB_PORT: 5432,

  // Elasticsearch (optional)
  // ------------------------
  ES_ENABLED: true,
  ES_HOST: 'https://satania-social.es.us-central1.gcp.cloud.es.io',
  ES_PORT: 443,
  ES_USER: 'elastic',

  // Sending mail
  // ------------
  SMTP_SERVER: 'smtp.mailgun.org',
  SMTP_PORT: 587,
  SMTP_LOGIN: 'notifications@satania.social',
  SMTP_FROM_ADDRESS: 'notifications@satania.social',

  // File storage (optional)
  // -----------------------
  S3_ENABLED: true,
  S3_PERMISSION: 'private',
  S3_ENDPOINT: 'https://c41358b3e2e8f5345933f0d433e3abef.r2.cloudflarestorage.com',
  S3_BUCKET: 'media-satania-social',
  S3_ALIAS_HOST: 'media.satania.social',

  // IP and session retention
  // -----------------------
  // Make sure to modify the scheduling of ip_cleanup_scheduler in config/sidekiq.yml
  // to be less than daily if you lower IP_RETENTION_PERIOD below two days (172800).
  // -----------------------
  IP_RETENTION_PERIOD: 31556952,
  SESSION_RETENTION_PERIOD: 31556952,
};

// Ensure that all values are strings.
{ [k]: std.toString(config[k]) for k in std.objectFields(config) }
