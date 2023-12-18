{%- if salt['elife.cfg']('cfn.outputs.DomainName') -%}
{%- set external_url = "https://" + salt['elife.cfg']('project.full_hostname') -%}
{% else %}
{%- set external_url = "http://localhost" -%}
{%- endif -%}

external-volume-ready:
    cmd.run:
        - name: echo "/ext ready"
        - require:
            - resize-external-volume-if-needed

# prometheus

prometheus-user-group:
    group.present:
        - name: prometheus

    user.present:
        - name: prometheus
        - shell: /bin/false
        - createhome: false
        - groups:
            - prometheus
        - require:
            - group: prometheus

# lsh@2023-12-15: temporary, once all instances no longer have such dir
prometheus-home-absent:
    file.absent:
        - name: /home/prometheus
        - require:
            - prometheus-user-group

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

prometheus-rules-config:
    file.managed:
        - name: /etc/prometheus.rules-config.yml
        - source: salt://monitor/config/etc-prometheus.rules-config.yml
        - template: jinja

    cmd.run:
        - name: /srv/prometheus/promtool check rules /etc/prometheus.rules-config.yml
        - require:
            - file: prometheus-rules-config

prometheus-config:
    file.managed:
        - name: /etc/prometheus.yml
        - source: salt://monitor/config/etc-prometheus.yml
        - template: jinja
        - require:
            - prometheus-rules-config

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
        - name: /ext/prometheus-data
        - user: prometheus
        - group: prometheus
        - require:
            - prometheus-user-group
            - external-volume-ready

prometheus-systemd-service:
    file.managed:
        - name: /lib/systemd/system/prometheus.service
        - source: salt://monitor/config/lib-systemd-system-prometheus.service
        - template: jinja
        - defaults:
            external_url: {{ external_url }}

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
        - createhome: false
        - groups:
            - grafana
        - require:
            - group: grafana

# lsh@2023-12-15: temporary, once all instances no longer have such dir
grafana-home-absent:
    file.absent:
        - name: /home/grafana
        - require:
            - grafana-user-group

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
        - name: /ext/grafana-data
        - user: grafana
        - group: grafana
        - require:
            - grafana-user-group
            - external-volume-ready

grafana-config-dir:
    file.directory:
        - name: /etc/grafana

grafana-provisioning-config-dir:
    file.directory:
        - name: /etc/grafana/provisioning
        - require:
            - grafana-config-dir


# sudo -u grafana ./bin/grafana cli --config /etc/grafana/grafana.ini --pluginsDir "/ext/grafana-data/plugins/" admin reset-admin-password foobarbaz

grafana-env-config:
    file.managed:
        - name: /etc/grafana/grafana-server.env
        - source: salt://monitor/config/etc-grafana-grafana-server.env
        - template: jinja
        - require:
            - grafana-config-dir

grafana-ini-config:
    file.managed:
        - name: /etc/grafana/grafana.ini
        - source: salt://monitor/config/etc-grafana-grafana.ini
        - template: jinja
        - require:
            - grafana-config-dir

grafana-plugins-dir:
    file.directory:
        - name: /var/lib/grafana/plugins
        - user: grafana
        - group: grafana
        - makedirs: true

{% for plugin, plugin_version in pillar.monitor.grafana.plugins.items() %}
grafana-plugin {{ plugin }}:
    cmd.run:
        - runas: grafana
        - cwd: /srv/grafana
        - name: ./bin/grafana cli --config /etc/grafana/grafana.ini plugins install {{ plugin }} {{ plugin_version }}
        - require:
            - grafana-plugins-dir
            - grafana-ini-config
            - grafana-ownership
        - require_in:
            - cmd: grafana-plugins-installed
{% endfor %}

grafana-plugins-installed:
    cmd.run:
        - name: echo "grafana plugins installed"

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
            - grafana-plugins-installed
        - require:
            - file: grafana-systemd-service
            - grafana-installation
            - grafana-ownership
            - grafana-env-config
            - grafana-ini-config
            - grafana-log-dir
            - grafana-plugins-installed

# AlertManager

alertmanager-user-group:
    group.present:
        - name: alertmanager

    user.present:
        - name: alertmanager
        - shell: /bin/false
        - createhome: false
        - groups:
            - alertmanager
        - require:
            - group: alertmanager

# lsh@2023-12-15: temporary, once all instances no longer have such dir
alertmanager-home-absent:
    file.absent:
        - name: /home/alertmanager
        - require:
            - alertmanager-user-group

alertmanager-installation:
    archive.extracted:
        - name: /srv
        - source: https://github.com/prometheus/alertmanager/releases/download/v0.25.0/alertmanager-0.25.0.linux-amd64.tar.gz
        - source_hash: 206cf787c01921574ca171220bb9b48b043c3ad6e744017030fed586eb48e04b
        - if_missing: /srv/alertmanager-0.25.0.linux-amd64

    file.symlink:
        - name: /srv/alertmanager
        - target: /srv/alertmanager-0.25.0.linux-amd64
        - force: true
        - require:
            - archive: alertmanager-installation

alertmanager-ownership:
    file.directory:
        - name: /srv/alertmanager
        - allow_symlink: true
        - user: alertmanager
        - group: alertmanager
        - recurse:
            - user
            - group
        - require:
            - alertmanager-user-group
            - alertmanager-installation

alertmanager-config:
    file.managed:
        - name: /etc/alertmanager.yml
        - source: salt://monitor/config/etc-alertmanager.yml
        - template: jinja

    cmd.run:
        - name: /srv/alertmanager/amtool check-config /etc/alertmanager.yml
        - require:
            - file: alertmanager-config

alertmanager-data-dir:
    file.directory:
        - name: /ext/alertmanager-data
        - user: alertmanager
        - group: alertmanager
        - require:
            - alertmanager-user-group
            - external-volume-ready

alertmanager-web-config:
    file.managed:
        - name: /etc/alertmanager.web-config.yml
        - source: salt://monitor/config/etc-alertmanager.web-config.yml
        - template: jinja

alertmanager-systemd-service:
    file.managed:
        - name: /lib/systemd/system/alertmanager.service
        - source: salt://monitor/config/lib-systemd-system-alertmanager.service
        - template: jinja
        - defaults:
            external_url: {{ external_url }}

    service.running:
        - name: alertmanager
        - enable: true
        - watch:
            - alertmanager-config
        - require:
            - file: alertmanager-systemd-service
            - alertmanager-installation
            - alertmanager-ownership
            - alertmanager-config
            - alertmanager-data-dir
            - alertmanager-web-config

# YACE AWS exporter

yace-user-group:
    group.present:
        - name: yace

    user.present:
        - name: yace
        - shell: /bin/false
        - createhome: false
        - groups:
            - yace
        - require:
            - group: yace

# lsh@2023-12-15: temporary, once all instances no longer have such dir
yace-home-absent:
    file.absent:
        - name: /home/yace
        - require:
            - yace-user-group

yace-installation:
    archive.extracted:
        - name: /usr/local/bin
        - source: https://github.com/nerdswords/yet-another-cloudwatch-exporter/releases/download/v0.54.1/yet-another-cloudwatch-exporter_0.54.1_Linux_x86_64.tar.gz
        - source_hash: b93e080a429388e68aaa6f3745268f959e2d9f9e979508038bbcf05b5c300660
        - enforce_toplevel: false
        - if_missing: /usr/local/bin/yace

    file.managed:
        - name: /usr/local/bin/yace
        - user: yace
        - group: yace
        - require:
            - archive: yace-installation
            - yace-user-group

yace-config:
    file.managed:
        - name: /etc/yace.yml
        - source: salt://monitor/config/etc-yace.yml
        - template: jinja

    cmd.run:
        - name: /usr/local/bin/yace verify-config --config.file /etc/yace.yml
        - require:
            - file: alertmanager-config

yace-systemd-service:
    file.managed:
        - name: /lib/systemd/system/yace.service
        - source: salt://monitor/config/lib-systemd-system-yace.service
        - template: jinja

    service.running:
        - name: yace
        - enable: true
        - init_delay: 2 # seconds
        - watch:
            - yace-config
        - require:
            - file: yace-systemd-service
            - yace-installation
            - yace-config

# nginx reverse proxy

monitor-nginx-proxy:
    file.managed:
        - name: /etc/nginx/sites-enabled/monitor.conf
        - source: salt://monitor/config/etc-nginx-sites-enabled-monitor.conf
        - template: jinja
        - listen_in:
            - service: nginx-server-service

prometheus-nginx-proxy:
    file.absent:
        - name: /etc/nginx/sites-enabled/prometheus.conf
        - listen_in:
            - service: nginx-server-service

grafana-nginx-proxy:
    file.absent:
        - name: /etc/nginx/sites-enabled/grafana.conf
        - listen_in:
            - service: nginx-server-service

alertmanager-nginx-proxy:
    file.absent:
        - name: /etc/nginx/sites-enabled/alertmanager.conf
        - listen_in:
            - service: nginx-server-service
