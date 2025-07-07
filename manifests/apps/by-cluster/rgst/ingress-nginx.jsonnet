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
local k = import '../../../../vendor/jsonnet-libs/k.libsonnet';

// nginx creates a new ingress nginx instance
local nginx(name, node_name, cloudflare=false) = k.Container {
  // https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
  application: argo.HelmApplication(
    chart='ingress-nginx',
    repoURL='https://kubernetes.github.io/ingress-nginx',
    version='4.13.0',
    release_name=if name == null then null else name,
    app_name=if name == null then null else name,
    values={
      controller: {
        allowSnippetAnnotations: true,
        dnsPolicy: 'ClusterFirstWithHostNet',
        service: {
          type: 'ClusterIP',
        },
        hostPort: {
          enabled: true,
        },
        replicaCount: 1,
        nodeSelector: {
          'kubernetes.io/hostname': node_name,
        },
        ingressClassResource+: {
          enabled: false,
        },
        updateStrategy: {
          type: 'Recreate',
        },
      },
    } + if cloudflare then {
      controller+: {
        // Cloudflare Origin Pull
        extraVolumes: [{
          name: 'origin-pull-certificate',
          secret: {
            secretName: 'cloudflare-origin',
          },
        }],
        extraVolumeMounts: [{
          name: 'origin-pull-certificate',
          mountPath: '/var/lib/certificates/cloudflare',
        }],
        ingressClassResource+: {
          enabled: true,
        },
        config+: {
          'server-snippet': |||
            ssl_client_certificate /var/lib/certificates/cloudflare/cloudflare-origin.pem;
            ssl_verify_client on;
          |||,
          // curl https://www.cloudflare.com/ips-v4/ | sed 's/^/"/' | sed 's/$/",/' | pbcopy
          // curl https://www.cloudflare.com/ips-v6/ | sed 's/^/"/' | sed 's/$/",/' | pbcopy
          //
          // Last Updated: Jan 14, 2024
          'proxy-real-ip-cidr': std.join(',', [
            '173.245.48.0/20',
            '103.21.244.0/22',
            '103.22.200.0/22',
            '103.31.4.0/22',
            '141.101.64.0/18',
            '108.162.192.0/18',
            '190.93.240.0/20',
            '188.114.96.0/20',
            '197.234.240.0/22',
            '198.41.128.0/17',
            '162.158.0.0/15',
            '104.16.0.0/13',
            '104.24.0.0/14',
            '172.64.0.0/13',
            '131.0.72.0/22',
            '2400:cb00::/32',
            '2606:4700::/32',
            '2803:f800::/32',
            '2405:b500::/32',
            '2405:8100::/32',
            '2a06:98c0::/29',
            '2c0f:f248::/32',
          ]),

          // Trust Cloudflare's forwarded information.
          'use-forwarded-headers': 'true',
          'forwarded-for-header': 'CF-Connecting-IP',
        },
      },
    } else {},
  ),
  [if cloudflare then 'origin_secret' else null]: k._Object('v1', 'Secret', 'cloudflare-origin', $.application.namespace) {
    type: 'Opaque',
    stringData: {
      'cloudflare-origin.pem': |||
        -----BEGIN CERTIFICATE-----
        MIIGCjCCA/KgAwIBAgIIV5G6lVbCLmEwDQYJKoZIhvcNAQENBQAwgZAxCzAJBgNV
        BAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMRQwEgYDVQQLEwtPcmln
        aW4gUHVsbDEWMBQGA1UEBxMNU2FuIEZyYW5jaXNjbzETMBEGA1UECBMKQ2FsaWZv
        cm5pYTEjMCEGA1UEAxMab3JpZ2luLXB1bGwuY2xvdWRmbGFyZS5uZXQwHhcNMTkx
        MDEwMTg0NTAwWhcNMjkxMTAxMTcwMDAwWjCBkDELMAkGA1UEBhMCVVMxGTAXBgNV
        BAoTEENsb3VkRmxhcmUsIEluYy4xFDASBgNVBAsTC09yaWdpbiBQdWxsMRYwFAYD
        VQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlhMSMwIQYDVQQD
        ExpvcmlnaW4tcHVsbC5jbG91ZGZsYXJlLm5ldDCCAiIwDQYJKoZIhvcNAQEBBQAD
        ggIPADCCAgoCggIBAN2y2zojYfl0bKfhp0AJBFeV+jQqbCw3sHmvEPwLmqDLqynI
        42tZXR5y914ZB9ZrwbL/K5O46exd/LujJnV2b3dzcx5rtiQzso0xzljqbnbQT20e
        ihx/WrF4OkZKydZzsdaJsWAPuplDH5P7J82q3re88jQdgE5hqjqFZ3clCG7lxoBw
        hLaazm3NJJlUfzdk97ouRvnFGAuXd5cQVx8jYOOeU60sWqmMe4QHdOvpqB91bJoY
        QSKVFjUgHeTpN8tNpKJfb9LIn3pun3bC9NKNHtRKMNX3Kl/sAPq7q/AlndvA2Kw3
        Dkum2mHQUGdzVHqcOgea9BGjLK2h7SuX93zTWL02u799dr6Xkrad/WShHchfjjRn
        aL35niJUDr02YJtPgxWObsrfOU63B8juLUphW/4BOjjJyAG5l9j1//aUGEi/sEe5
        lqVv0P78QrxoxR+MMXiJwQab5FB8TG/ac6mRHgF9CmkX90uaRh+OC07XjTdfSKGR
        PpM9hB2ZhLol/nf8qmoLdoD5HvODZuKu2+muKeVHXgw2/A6wM7OwrinxZiyBk5Hh
        CvaADH7PZpU6z/zv5NU5HSvXiKtCzFuDu4/Zfi34RfHXeCUfHAb4KfNRXJwMsxUa
        +4ZpSAX2G6RnGU5meuXpU5/V+DQJp/e69XyyY6RXDoMywaEFlIlXBqjRRA2pAgMB
        AAGjZjBkMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/AgECMB0GA1Ud
        DgQWBBRDWUsraYuA4REzalfNVzjann3F6zAfBgNVHSMEGDAWgBRDWUsraYuA4REz
        alfNVzjann3F6zANBgkqhkiG9w0BAQ0FAAOCAgEAkQ+T9nqcSlAuW/90DeYmQOW1
        QhqOor5psBEGvxbNGV2hdLJY8h6QUq48BCevcMChg/L1CkznBNI40i3/6heDn3IS
        zVEwXKf34pPFCACWVMZxbQjkNRTiH8iRur9EsaNQ5oXCPJkhwg2+IFyoPAAYURoX
        VcI9SCDUa45clmYHJ/XYwV1icGVI8/9b2JUqklnOTa5tugwIUi5sTfipNcJXHhgz
        6BKYDl0/UP0lLKbsUETXeTGDiDpxZYIgbcFrRDDkHC6BSvdWVEiH5b9mH2BON60z
        0O0j8EEKTwi9jnafVtZQXP/D8yoVowdFDjXcKkOPF/1gIh9qrFR6GdoPVgB3SkLc
        5ulBqZaCHm563jsvWb/kXJnlFxW+1bsO9BDD6DweBcGdNurgmH625wBXksSdD7y/
        fakk8DagjbjKShYlPEFOAqEcliwjF45eabL0t27MJV61O/jHzHL3dknXeE4BDa2j
        bA+JbyJeUMtU7KMsxvx82RmhqBEJJDBCJ3scVptvhDMRrtqDBW5JShxoAOcpFQGm
        iYWicn46nPDjgTU0bX1ZPpTpryXbvciVL5RkVBuyX2ntcOLDPlZWgxZCBp96x07F
        AnOzKgZk4RzZPNAxCXERVxajn/FLcOhglVAKo5H0ac+AitlQ0ip55D2/mf8o72tM
        fVQ6VpyjEXdiIXWUq/o=
        -----END CERTIFICATE-----
      |||,
    },
  },
};

local all = {
  external: nginx(null, 'ruka', true),
  internal: nginx('internal-ingress-nginx', 'mocha'),  // Not exposed to the internet
};

k.List() { items_:: all }
