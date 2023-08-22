# prometheus

prometheus-user-group:
    group.present:
        - name: prometheus

    user.present:
        - name: prometheus
        - shell: /bin/false
        - groups:
            - prometheus
        - require:
            - group: prometheus

prometheus-installation:
    archive.extracted:
        - name: /srv
        - source: https://github.com/prometheus/prometheus/releases/download/v2.46.0/prometheus-2.46.0.linux-amd64.tar.gz
        - source_hash: d2177ea21a6f60046f9510c828d4f8969628cfd35686780b3898917ef9c268b9
        - if_missing: /srv/prometheus
        
    file.symlink:
        - name: /srv/prometheus
        - target: /srv/prometheus-2.46.0.linux-amd64
        - force: true
        - require:
            - archive: prometheus-installation

prometheus-ownership:
    file.directory:
        - name: /srv/prometheus
        - allow_symlink: true
        - user: prometheus
        - group: prometheus
        - recurse:
            - user
            - group
        - require:
            - prometheus-user-group
            - prometheus-installation

prometheus-config:
    file.managed:
        - name: /etc/prometheus.yml
        - source: salt://monitor/config/etc-prometheus.yml
        - template: jinja

    cmd.run:
        - name: /srv/prometheus/promtool check config /etc/prometheus.yml
        - require:
            - file: prometheus-config

prometheus-web-config:
    file.managed:
        - name: /etc/prometheus.web-config.yml
        - source: salt://monitor/config/etc-prometheus.web-config.yml
        - template: jinja

prometheus-data-dir:
    file.directory:
        - name: /srv/prometheus-data
        - user: prometheus
        - group: prometheus
        - require:
            - prometheus-user-group

prometheus-systemd-service:
    file.managed:
        - name: /lib/systemd/system/prometheus.service
        - source: salt://monitor/config/lib-systemd-system-prometheus.service

    service.running:
        - name: prometheus
        - enable: true
        - watch:
            - prometheus-config
        - require:
            - file: prometheus-systemd-service
            - prometheus-installation
            - prometheus-ownership
            - prometheus-config
            - prometheus-web-config
            - prometheus-data-dir

# grafana

grafana-user-group:
    group.present:
        - name: grafana

    user.present:
        - name: grafana
        - shell: /bin/false
        - groups:
            - grafana
        - require:
            - group: grafana

grafana-installation:
    archive.extracted:
        - name: /srv
        - source: https://dl.grafana.com/oss/release/grafana-10.0.3.linux-amd64.tar.gz
        - source_hash: daeb7eee1327b6d407cdaaf1a234ec9d8e2ae5a6d085e0fd3d8c606214eb6032
        - if_missing: /srv/grafana

    file.symlink:
        - name: /srv/grafana
        - target: /srv/grafana-10.0.3
        - force: true
        - require:
            - archive: grafana-installation

grafana-ownership:
    file.directory:
        - name: /srv/grafana
        - allow_symlink: true
        - user: grafana
        - group: grafana
        - recurse:
            - user
            - group
        - require:
            - grafana-user-group
            - grafana-installation

grafana-log-dir:
    file.directory:
        - name: /var/log/grafana

grafana-data-dir:
    file.directory:
        - name: /srv/grafana-data
        - user: grafana
        - group: grafana

grafana-config-dir:
    file.directory:
        - name: /etc/grafana

grafana-provisioning-config-dir:
    file.directory:
        - name: /etc/grafana/provisioning
        - require:
            - grafana-config-dir

grafana-env-config:
    file.managed:
        - name: /etc/grafana/grafana-server.env
        - source: salt://monitor/config/etc-grafana-grafana-server.env
        - require:
            - grafana-config-dir

grafana-ini-config:
    file.managed:
        - name: /etc/grafana/grafana.ini
        - source: salt://monitor/config/etc-grafana-grafana.ini
        - require:
            - grafana-config-dir

grafana-systemd-service:
    file.managed:
        - name: /lib/systemd/system/grafana.service
        - source: salt://monitor/config/lib-systemd-system-grafana.service

    service.running:
        - name: grafana
        - enable: true
        - watch:
            - grafana-ini-config
            - grafana-env-config
        - require:
            - file: grafana-systemd-service
            - grafana-installation
            - grafana-ownership
            - grafana-env-config
            - grafana-ini-config
            - grafana-log-dir

# reverse proxy

prometheus-nginx-proxy:
    file.managed:
        - name: /etc/nginx/sites-enabled/prometheus.conf
        - source: salt://monitor/config/etc-nginx-sites-enabled-prometheus.conf
        - template: jinja
        - listen_in:
            - service: nginx-server-service

grafana-nginx-proxy:
    file.managed:
        - name: /etc/nginx/sites-enabled/grafana.conf
        - source: salt://monitor/config/etc-nginx-sites-enabled-grafana.conf
        - template: jinja
        - listen_in:
            - service: nginx-server-service
