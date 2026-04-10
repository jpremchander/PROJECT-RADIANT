FROM ghcr.io/misp/misp-docker/misp-core:latest

USER root

COPY config/ /var/www/MISP/app/Config/

RUN mkdir -p /var/log/misp \
    && chown -R www-data:www-data /var/log/misp /var/www/MISP/app/Config

EXPOSE 80

USER www-data