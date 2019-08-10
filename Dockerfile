FROM ubuntu:18.04

ENV TERM xterm-256color
ENV DEBIAN_FRONTEND noninteractive

RUN echo "nameserver 1.1.1.1" > /etc/resolv.conf \
    && apt update ; apt install -yq software-properties-common \
    && add-apt-repository ppa:shevchuk/dnscrypt-proxy \
    && apt update ; apt install -yq dnsmasq dnscrypt-proxy php7.2-cli php7.2-yaml cron curl
RUN echo 'user=root' >> /etc/dnsmasq.conf
RUN echo 'no-resolv' >> /etc/dnsmasq.conf
RUN echo 'server=127.0.0.1#53' >> /etc/dnsmasq.conf
#RUN echo 'log-queries' >> /etc/dnsmasq.conf
RUN echo 'log-facility=/var/log/dnsmasq.log' >> /etc/dnsmasq.conf
RUN echo 'addn-hosts=/data/hosts' >> /etc/dnsmasq.conf
RUN echo 'conf-dir=/data/confs' >> /etc/dnsmasq.conf
RUN echo 'port=5353' >> /etc/dnsmasq.conf
RUN echo '10 0 * * * curl -Ls https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt > /data/hosts/notracking' >> /tmp/cron
RUN echo '20 0 * * * curl -Ls https://raw.githubusercontent.com/notracking/hosts-blocklists/master/domains.txt > /data/confs/notracking' >> /tmp/cron
RUN echo '30 0 * * * service dnsmasq restart' >> /tmp/cron
RUN sed -i 's|require_dnssec = .*|require_dnssec = true|' /etc/dnscrypt-proxy/dnscrypt-proxy.toml
RUN sed -i 's|ipv6_servers = .*|ipv6_servers = true|' /etc/dnscrypt-proxy/dnscrypt-proxy.toml
RUN sed -i 's|listen_addresses = .*|listen_addresses = ["127.0.0.1:53"]|' /etc/dnscrypt-proxy/dnscrypt-proxy.toml
RUN crontab /tmp/cron
RUN mkdir -p /data/confs

ADD lists.d /data/lists
ADD hosts.d /data/hosts
ADD build.php /data/build.php

ENTRYPOINT service cron start \
           && /usr/bin/php /data/build.php \
           && dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml & echo \
           && service dnsmasq restart \
           && curl -Ls https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt > /data/hosts/notracking || true \
           && curl -Ls https://raw.githubusercontent.com/notracking/hosts-blocklists/master/domains.txt > /data/confs/notracking || true \
           && service dnsmasq restart \
           && tail -f /var/log/dnsmasq.log
