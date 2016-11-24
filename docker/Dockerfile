# TransparentVault DockerFile
# by Chris F. Ravenscroft

# Pull Dropbox image by Jan B and S6 overlay by Tutum
FROM janeczku/dropbox
ADD https://github.com/just-containers/s6-overlay/releases/download/v1.18.1.5/s6-overlay-amd64.tar.gz /tmp/
MAINTAINER Chris F. Ravenscroft <chris@voilaweb.com>

LABEL Description="A self contained zero-knowledge Vault instance"
EXPOSE 3000

# Note: we are retrieving crystal through http, not https
# Work: merge s6 overlay; setup dropbox supervision; setup vault supervision; setup crystal + vault

RUN tar zxf /tmp/s6-overlay-amd64.tar.gz -C / && \
    \
    head -n -3 /root/run > /etc/cont-init.d/run && \
    \
    mkdir -p /etc/services.d/dropbox && \
    echo '#!/usr/bin/with-contenv bash' > /etc/services.d/dropbox/run && \
    tail -n -3 /root/run >> /etc/services.d/dropbox/run && \
    sed -i 's/dropboxd/dropboxd > \/var\/log\/dropbox/' /etc/services.d/dropbox/run && \
    echo "if [ ! -z \"\$HTTP_PROXY\" ]; then export http_proxy=\$HTTP_PROXY; fi; if [ ! -z "\$HTTPS_PROXY" ]; then export https_proxy=\$HTTPS_PROXY; fi" > /etc/naive_proxy_settings && \
    sed -i 's/# This/source \/etc\/naive_proxy_settings; # This/' /etc/services.d/dropbox/run && \
    ln -s /bin/true /etc/services.d/dropbox/finish && \
    \
    mkdir -p /etc/services.d/vault && \
    echo '#!/usr/bin/with-contenv bash' > /etc/services.d/vault/run && \
    echo 'while [[ "$(/usr/bin/dropbox status)" == Starting* || "$(/usr/bin/dropbox status)" == Dropbox* ]]; do sleep 5; done' >> /etc/services.d/vault/run && \
    echo 'unlink /var/www/transparentvault/data/data' >> /etc/services.d/vault/run && \
    echo 'mkdir -p /dbox/Dropbox/vault/data' >> /etc/services.d/vault/run && \
    echo 'ln -s /dbox/Dropbox/vault/data  /var/www/transparentvault/data/data' >> /etc/services.d/vault/run && \
    echo 'cd /var/www/transparentvault && crystal src/backend.cr > /var/log/vault 2>&1' >> /etc/services.d/vault/run && \
    \
    apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54 && \
    echo "deb http://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list && \
    apt-get update && \
    apt-get install -y git pkg-config libssl-dev build-essential && \
    apt-get install -y crystal=0.20.0-1 && \
    \
    mkdir /var/www && \
    cd /var/www && \
    git clone https://github.com/Fusion/transparentvault.git && \
    cd /var/www/transparentvault && \
    shards install && \
    mkdir -p data/auth data/keys data/logs && \
    \
    echo '#!/bin/sh' >  /root/run

ENTRYPOINT ["/init"]
CMD []
